import 'dart:math';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../../shared/database/database_helper.dart';
import '../models/sensor_data.dart';
import '../models/tremor_result.dart';
import '../models/tremor_session.dart';

/// Signal processing pipeline for Parkinson's tremor analysis.
///
/// Implements a full pipeline:
///   1. DC-offset removal
///   2. Butterworth bandpass filter (1–12 Hz, order 4)
///   3. FFT with Hanning window
///   4. Dominant frequency identification (3–7 Hz tremor band)
///   5. Tremor power / total power calculation
///   6. UPDRS tremor score classification
class TremorAnalysisService {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Runs the complete analysis pipeline on [buffer].
  ///
  /// Returns an [AppError] with [AnalysisFailure] when:
  /// - The buffer contains fewer than 30 seconds of data.
  /// - The signal variance is too low (sensor likely not worn).
  Future<Result<TremorResult>> analyzeBuffer(
      SensorDataBuffer buffer) async {
    if (!buffer.hasMinimumData) {
      return const AppError(AnalysisFailure(
          'Recording must be at least 30 seconds long.'));
    }

    final magnitudes = buffer.accelMagnitudes;
    if (_signalVariance(magnitudes) < _kMinVariance) {
      return const AppError(AnalysisFailure(
          'Signal quality too low. Ensure the sensor is properly worn.'));
    }

    try {
      final fs = buffer.samplingRateHz;

      // Step 1: Remove DC offset.
      final detrended = removeDcOffset(magnitudes);

      // Step 2: Bandpass filter 1–12 Hz.
      final filtered = bandpassFilter(detrended, fs);

      // Step 3: FFT.
      final fftResult = computeFFT(filtered, fs);

      // Step 4: Dominant frequency in 3–7 Hz.
      final dominantHz = findDominantFrequency(fftResult);

      // Step 5 & 6: Power calculations.
      final tremorPower = calculateTremorPower(fftResult);
      final totalPower = calculateTotalPower(fftResult);
      final tremorRatio =
          totalPower > 0 ? tremorPower / totalPower : 0.0;

      // Step 7: UPDRS classification.
      final updrsScore = classifyTremor(tremorRatio);
      const labels = [
        'No tremor',
        'Slight',
        'Mild',
        'Moderate',
        'Severe'
      ];
      final updrsLabel = labels[updrsScore.clamp(0, 4)];

      final result = TremorResult(
        updrsScore: updrsScore,
        updrsLabel: updrsLabel,
        dominantFrequencyHz: dominantHz,
        tremorRatio: tremorRatio,
        tremorPower: tremorPower,
        totalPower: totalPower,
        fftResult: fftResult,
        recordingDuration: Duration(
            milliseconds:
                (buffer.durationSeconds * 1000).round()),
        samplingRateHz: fs,
      );

      return Success(result);
    } catch (e) {
      return AppError(AnalysisFailure('Analysis failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Step 1 – DC offset removal
  // ---------------------------------------------------------------------------

  /// Removes the mean (DC offset) from [signal].
  List<double> removeDcOffset(List<double> signal) {
    if (signal.isEmpty) return [];
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    return signal.map((v) => v - mean).toList();
  }

  // ---------------------------------------------------------------------------
  // Step 2 – Butterworth bandpass filter
  // ---------------------------------------------------------------------------

  /// Applies a zero-phase 4th-order Butterworth bandpass filter to [signal].
  ///
  /// The filter is implemented as cascaded 2nd-order sections:
  /// a 2nd-order Butterworth high-pass at [lowCutoff] Hz followed by a
  /// 2nd-order Butterworth low-pass at [highCutoff] Hz. Zero-phase
  /// response is achieved by filtering forward then backward.
  List<double> bandpassFilter(
    List<double> signal,
    double samplingRate, {
    double lowCutoff = 1.0,
    double highCutoff = 12.0,
  }) {
    if (signal.isEmpty) return [];

    // Design biquad coefficients.
    final hp = _butterworthHP2(lowCutoff, samplingRate);
    final lp = _butterworthLP2(highCutoff, samplingRate);

    // Forward pass: HP then LP.
    var y = _applyBiquad(signal, hp);
    y = _applyBiquad(y, lp);

    // Backward pass (zero-phase): reverse, HP, LP, reverse.
    y = y.reversed.toList();
    y = _applyBiquad(y, hp);
    y = _applyBiquad(y, lp);
    y = y.reversed.toList();

    return y;
  }

  // ---------------------------------------------------------------------------
  // Step 3 – FFT
  // ---------------------------------------------------------------------------

  /// Computes a windowed FFT of [signal] sampled at [samplingRate] Hz.
  ///
  /// A Hanning window is applied before the transform. The input is
  /// zero-padded to the next power of 2.  The returned [FftResult]
  /// contains the single-sided amplitude spectrum.
  FftResult computeFFT(List<double> signal, double samplingRate) {
    if (signal.isEmpty) {
      return const FftResult(frequencies: [], amplitudes: []);
    }

    // Zero-pad to next power of 2.
    final n = _nextPow2(signal.length);
    final windowed = List<double>.filled(n, 0.0);
    for (var i = 0; i < signal.length; i++) {
      // Hanning window.
      final w = 0.5 * (1.0 - cos(2.0 * pi * i / (signal.length - 1)));
      windowed[i] = signal[i] * w;
    }

    // Complex FFT arrays.
    final real = List<double>.from(windowed);
    final imag = List<double>.filled(n, 0.0);
    _fftInPlace(real, imag);

    // Single-sided amplitude spectrum.
    final halfN = n ~/ 2 + 1;
    final freqResolution = samplingRate / n;
    final frequencies = List<double>.generate(
        halfN, (i) => i * freqResolution);
    final amplitudes = List<double>.generate(halfN, (i) {
      final amp = sqrt(real[i] * real[i] + imag[i] * imag[i]) / n;
      // Double the amplitude for non-DC, non-Nyquist bins.
      return (i == 0 || i == halfN - 1) ? amp : amp * 2;
    });

    return FftResult(
      frequencies: frequencies,
      amplitudes: amplitudes,
      frequencyResolution: freqResolution,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4 – Dominant frequency
  // ---------------------------------------------------------------------------

  /// Returns the frequency of the highest-amplitude bin in [[minFreq], [maxFreq]].
  ///
  /// Returns 0.0 when no bin falls within the specified range.
  double findDominantFrequency(
    FftResult fftResult, {
    double minFreq = 3.0,
    double maxFreq = 7.0,
  }) {
    var maxAmp = 0.0;
    var dominantHz = 0.0;
    for (var i = 0; i < fftResult.frequencies.length; i++) {
      final f = fftResult.frequencies[i];
      if (f >= minFreq && f <= maxFreq) {
        if (fftResult.amplitudes[i] > maxAmp) {
          maxAmp = fftResult.amplitudes[i];
          dominantHz = f;
        }
      }
    }
    return dominantHz;
  }

  // ---------------------------------------------------------------------------
  // Step 5 & 6 – Power calculations
  // ---------------------------------------------------------------------------

  /// Calculates the tremor band power (area under curve) in [[minFreq], [maxFreq]].
  double calculateTremorPower(
    FftResult fftResult, {
    double minFreq = 3.0,
    double maxFreq = 7.0,
  }) =>
      _bandPower(fftResult, minFreq, maxFreq);

  /// Calculates the total signal power in [[minFreq], [maxFreq]].
  double calculateTotalPower(
    FftResult fftResult, {
    double minFreq = 1.0,
    double maxFreq = 12.0,
  }) =>
      _bandPower(fftResult, minFreq, maxFreq);

  // ---------------------------------------------------------------------------
  // Step 7 – UPDRS classification
  // ---------------------------------------------------------------------------

  /// Maps [tremorRatio] to a UPDRS tremor score (0–4).
  ///
  /// | Score | Label    | Tremor ratio |
  /// |-------|----------|--------------|
  /// | 0     | No tremor| < 0.05       |
  /// | 1     | Slight   | 0.05–0.15    |
  /// | 2     | Mild     | 0.15–0.30    |
  /// | 3     | Moderate | 0.30–0.50    |
  /// | 4     | Severe   | > 0.50       |
  int classifyTremor(double tremorRatio) {
    if (tremorRatio < 0.05) return 0;
    if (tremorRatio < 0.15) return 1;
    if (tremorRatio < 0.30) return 2;
    if (tremorRatio < 0.50) return 3;
    return 4;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Saves [session] metadata to the `tremor_sessions` SQLite table.
  Future<Result<void>> saveSession(TremorSession session) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('tremor_sessions', session.toMap());
      return const Success(null);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to save session: $e'));
    }
  }

  /// Returns past sessions ordered by descending timestamp.
  ///
  /// Pass [limit] to restrict the number of results.
  Future<Result<List<TremorSession>>> getSessions({int? limit}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'tremor_sessions',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      final sessions =
          rows.map(TremorSession.fromMap).toList();
      return Success(sessions);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to load sessions: $e'));
    }
  }

  /// Saves raw sensor data for [sessionId] in a single batched transaction.
  Future<Result<void>> saveRawData(
      String sessionId, List<SensorDataPoint> data) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final point in data) {
          batch.insert('tremor_raw_data', {
            'session_id': sessionId,
            ...point.toMap(),
          });
        }
        await batch.commit(noResult: true);
      });
      return const Success(null);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to save raw data: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Minimum signal variance below which the signal is considered invalid.
  static const double _kMinVariance = 1e-6;

  double _signalVariance(List<double> signal) {
    if (signal.length < 2) return 0.0;
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final sumSq = signal.fold<double>(
        0.0, (acc, v) => acc + (v - mean) * (v - mean));
    return sumSq / signal.length;
  }

  double _bandPower(FftResult fft, double minFreq, double maxFreq) {
    var power = 0.0;
    for (var i = 0; i < fft.frequencies.length; i++) {
      final f = fft.frequencies[i];
      if (f >= minFreq && f <= maxFreq) {
        power += fft.amplitudes[i] * fft.amplitudes[i];
      }
    }
    return power;
  }

  // ── Biquad filter design ──────────────────────────────────────────────────

  /// Designs a 2nd-order Butterworth low-pass biquad at [fc] Hz.
  ///
  /// Returns coefficients [b0, b1, b2, a1, a2] (a0 normalised to 1).
  List<double> _butterworthLP2(double fc, double fs) {
    final k = tan(pi * fc / fs);
    final k2 = k * k;
    final sqrt2k = sqrt(2.0) * k;
    final norm = 1.0 / (1.0 + sqrt2k + k2);
    final b0 = k2 * norm;
    final b1 = 2.0 * k2 * norm;
    final b2 = b0;
    final a1 = 2.0 * (k2 - 1.0) * norm;
    final a2 = (1.0 - sqrt2k + k2) * norm;
    return [b0, b1, b2, a1, a2];
  }

  /// Designs a 2nd-order Butterworth high-pass biquad at [fc] Hz.
  ///
  /// Returns coefficients [b0, b1, b2, a1, a2] (a0 normalised to 1).
  List<double> _butterworthHP2(double fc, double fs) {
    final k = tan(pi * fc / fs);
    final k2 = k * k;
    final sqrt2k = sqrt(2.0) * k;
    final norm = 1.0 / (1.0 + sqrt2k + k2);
    final b0 = norm;
    final b1 = -2.0 * norm;
    final b2 = norm;
    final a1 = 2.0 * (k2 - 1.0) * norm;
    final a2 = (1.0 - sqrt2k + k2) * norm;
    return [b0, b1, b2, a1, a2];
  }

  /// Applies a biquad IIR filter defined by [coeffs] = [b0, b1, b2, a1, a2].
  List<double> _applyBiquad(List<double> x, List<double> coeffs) {
    final b0 = coeffs[0];
    final b1 = coeffs[1];
    final b2 = coeffs[2];
    final a1 = coeffs[3];
    final a2 = coeffs[4];

    final y = List<double>.filled(x.length, 0.0);
    var w1 = 0.0;
    var w2 = 0.0;

    for (var n = 0; n < x.length; n++) {
      final w0 = x[n] - a1 * w1 - a2 * w2;
      y[n] = b0 * w0 + b1 * w1 + b2 * w2;
      w2 = w1;
      w1 = w0;
    }
    return y;
  }

  // ── FFT ──────────────────────────────────────────────────────────────────

  /// Returns the smallest power of 2 that is ≥ [n].
  int _nextPow2(int n) {
    var p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  /// In-place Cooley–Tukey radix-2 DIT FFT.
  ///
  /// [real] and [imag] must have the same length, which must be a power of 2.
  void _fftInPlace(List<double> real, List<double> imag) {
    final n = real.length;
    assert(n > 0 && (n & (n - 1)) == 0, 'n must be a power of 2');

    // Bit-reversal permutation.
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        var tmp = real[i];
        real[i] = real[j];
        real[j] = tmp;
        tmp = imag[i];
        imag[i] = imag[j];
        imag[j] = tmp;
      }
    }

    // Butterfly stages.
    for (var len = 2; len <= n; len <<= 1) {
      final halfLen = len >> 1;
      final ang = -2.0 * pi / len;
      final wRe = cos(ang);
      final wIm = sin(ang);

      for (var i = 0; i < n; i += len) {
        var cRe = 1.0;
        var cIm = 0.0;
        for (var k = 0; k < halfLen; k++) {
          final uRe = real[i + k];
          final uIm = imag[i + k];
          final vRe =
              real[i + k + halfLen] * cRe - imag[i + k + halfLen] * cIm;
          final vIm =
              real[i + k + halfLen] * cIm + imag[i + k + halfLen] * cRe;
          real[i + k] = uRe + vRe;
          imag[i + k] = uIm + vIm;
          real[i + k + halfLen] = uRe - vRe;
          imag[i + k + halfLen] = uIm - vIm;
          final newCRe = cRe * wRe - cIm * wIm;
          cIm = cRe * wIm + cIm * wRe;
          cRe = newCRe;
        }
      }
    }
  }
}
