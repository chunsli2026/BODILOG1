import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/error/result.dart';
import '../../../core/error/failures.dart';
import '../models/sensor_data.dart';
import '../models/tremor_result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FFT
// ─────────────────────────────────────────────────────────────────────────────

/// Pure-Dart Cooley–Tukey radix-2 FFT implementation.
class FFT {
  const FFT();

  /// Perform a forward DFT using the Cooley–Tukey algorithm.
  ///
  /// The [signal] is zero-padded internally to the next power of two if
  /// its length is not already a power of two.
  List<({double real, double imag})> forward(List<double> signal) {
    final padded = zeroPad(signal);
    final n = padded.length;

    // Build complex working array.
    final re = List<double>.from(padded);
    final im = List<double>.filled(n, 0.0);

    _fftInPlace(re, im, n);

    return List.generate(n, (k) => (real: re[k], imag: im[k]));
  }

  void _fftInPlace(List<double> re, List<double> im, int n) {
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
        final tmpR = re[i];
        re[i] = re[j];
        re[j] = tmpR;
        final tmpI = im[i];
        im[i] = im[j];
        im[j] = tmpI;
      }
    }

    // Butterfly passes.
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wRe = math.cos(ang);
      final wIm = math.sin(ang);

      for (var i = 0; i < n; i += len) {
        var curRe = 1.0;
        var curIm = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final uRe = re[i + k];
          final uIm = im[i + k];
          final vRe = re[i + k + len ~/ 2] * curRe - im[i + k + len ~/ 2] * curIm;
          final vIm = re[i + k + len ~/ 2] * curIm + im[i + k + len ~/ 2] * curRe;

          re[i + k] = uRe + vRe;
          im[i + k] = uIm + vIm;
          re[i + k + len ~/ 2] = uRe - vRe;
          im[i + k + len ~/ 2] = uIm - vIm;

          final newCurRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = newCurRe;
        }
      }
    }
  }

  /// Compute the amplitude spectrum from complex FFT output.
  List<double> magnitudeSpectrum(List<({double real, double imag})> fftOutput) {
    return fftOutput
        .map((c) => math.sqrt(c.real * c.real + c.imag * c.imag))
        .toList();
  }

  /// Generate frequency bins for a signal of [signalLength] samples at
  /// [samplingRate] Hz.  Only the first N/2 + 1 bins are meaningful.
  List<double> frequencyBins(int signalLength, double samplingRate) {
    final n = signalLength;
    final resolution = samplingRate / n;
    return List.generate(n ~/ 2 + 1, (k) => k * resolution);
  }

  /// Zero-pad [signal] to the next power of two.
  List<double> zeroPad(List<double> signal) {
    final target = nextPowerOfTwo(signal.length);
    if (target == signal.length) return List.from(signal);
    return [...signal, ...List.filled(target - signal.length, 0.0)];
  }

  /// Returns `true` when [n] is an exact power of two.
  bool isPowerOfTwo(int n) => n > 0 && (n & (n - 1)) == 0;

  /// Returns the smallest power of two that is ≥ [n].
  int nextPowerOfTwo(int n) {
    if (isPowerOfTwo(n)) return n;
    var p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tremor Analysis Service
// ─────────────────────────────────────────────────────────────────────────────

/// Signal-processing pipeline for Parkinsonian tremor detection.
///
/// Processing stages:
/// 1. Pre-processing  — DC-offset removal, bandpass filtering (1–12 Hz)
/// 2. Feature extraction — FFT, dominant frequency, tremor power ratio
/// 3. Classification — UPDRS score (0–4)
class TremorAnalysisService {
  TremorAnalysisService() : _fft = const FFT();

  final FFT _fft;

  // Minimum polynomial evaluation result to prevent division by zero in normalization.
  static const double _minPolyEval = 1e-10;

  // ── Public entry point ──────────────────────────────────────────────────

  /// Run the full tremor analysis pipeline on [data] recorded at
  /// [samplingRate] Hz.
  ///
  /// Requires at least 30 seconds of data.
  Future<Result<TremorResult>> analyzeRecording(
    List<SensorData> data,
    double samplingRate,
  ) async {
    if (!isDurationSufficient(data, samplingRate)) {
      return const AppError(
        AnalysisFailure('Recording too short. At least 30 seconds required.'),
      );
    }

    try {
      // Step 1 – pre-processing.
      final raw = computeMagnitude(data);
      final dcRemoved = removeDcOffset(raw);
      final filtered = bandpassFilter(dcRemoved, samplingRate);

      // Signal quality check.
      if (!isSignalQualityAdequate(filtered)) {
        return const AppError(
          AnalysisFailure(
            'Signal quality too low. Ensure sensor is worn correctly.',
          ),
        );
      }

      // Step 2 – feature extraction.
      final (:frequencies, :amplitudes) = performFft(filtered, samplingRate);
      final dominantFreq =
          findDominantFrequency(frequencies, amplitudes);
      final tremorPow = calculateTremorPower(frequencies, amplitudes);
      final totalPow = calculateTotalPower(frequencies, amplitudes);
      final ratio = calculateTremorRatio(tremorPow, totalPow);

      // Step 3 – classification.
      final score = classifyTremor(ratio, dominantFreq);
      final label = getUpdrsLabel(score);

      final durationSecs =
          (data.length / samplingRate).round();

      // Trim FFT output to 0–20 Hz for display.
      final maxIdx = frequencies.lastIndexWhere((f) => f <= 20.0);
      final displayFreqs = frequencies.sublist(0, maxIdx + 1);
      final displayAmps = amplitudes.sublist(0, maxIdx + 1);

      return Success(
        TremorResult(
          updrsScore: score,
          updrsLabel: label,
          dominantFrequency: dominantFreq,
          tremorRatio: ratio,
          tremorPower: tremorPow,
          totalPower: totalPow,
          fftFrequencies: displayFreqs,
          fftAmplitudes: displayAmps,
          samplingRate: samplingRate,
          durationSeconds: durationSecs,
          analyzedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      return AppError(AnalysisFailure('Analysis failed: $e'));
    }
  }

  // ── Step 1: Pre-processing ──────────────────────────────────────────────

  /// Remove the DC component by subtracting the mean.
  List<double> removeDcOffset(List<double> signal) {
    if (signal.isEmpty) return [];
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    return signal.map((v) => v - mean).toList();
  }

  /// Apply a 4th-order Butterworth bandpass filter (1–12 Hz).
  List<double> bandpassFilter(
    List<double> signal,
    double samplingRate, {
    double lowCutoff = 1.0,
    double highCutoff = 12.0,
    int order = 4,
  }) {
    final (:b, :a) =
        butterworthCoefficients(samplingRate, lowCutoff, highCutoff, order);
    return applyIirFilter(signal, b, a);
  }

  /// Calculate second-order section (SOS) Butterworth coefficients via the
  /// bilinear transform.
  ///
  /// Returns cascade b/a coefficients for the combined filter.
  ({List<double> b, List<double> a}) butterworthCoefficients(
    double samplingRate,
    double lowCutoff,
    double highCutoff,
    int order,
  ) {
    // Normalised digital cutoff frequencies (0..π → 0..1).
    final dt = 1.0 / samplingRate;
    final wLow = 2 * math.pi * lowCutoff * dt;
    final wHigh = 2 * math.pi * highCutoff * dt;

    // Pre-warp for bilinear transform.
    final omegaLow = 2.0 * samplingRate * math.tan(wLow / 2.0);
    final omegaHigh = 2.0 * samplingRate * math.tan(wHigh / 2.0);

    // Bandwidth and centre frequency of the prototype bandpass.
    final bw = omegaHigh - omegaLow;
    final omega0 = math.sqrt(omegaLow * omegaHigh);

    // Build second-order section cascade for order/2 poles.
    // For a bandpass filter, each analog lowpass pole maps to 2 digital poles
    // so we use order/2 prototype poles.
    final halfOrder = math.max(1, order ~/ 2);

    // Initialise result as identity filter (passthrough).
    var bCoeffs = [1.0];
    var aCoeffs = [1.0];

    for (var k = 1; k <= halfOrder; k++) {
      // Analog prototype pole on unit circle.
      final theta = math.pi * (2 * k - 1) / (2 * halfOrder);
      final pRe = -math.sin(theta) * bw / 2.0;
      final pIm = omega0;

      // Map to digital domain via bilinear transform.
      final c = 2.0 * samplingRate;
      final dRe = pRe / c;
      final dIm = pIm / c;

      final r = math.sqrt(dRe * dRe + dIm * dIm);
      final angle = math.atan2(dIm, dRe);

      // Digital pole pair.
      final a1 = -2 * r * math.cos(angle);
      final a2 = r * r;

      // Combine new section with existing.
      bCoeffs = _polyMul(bCoeffs, [1.0, 0.0, -1.0]); // bandpass zero pair
      aCoeffs = _polyMul(aCoeffs, [1.0, a1, a2]);
    }

    // Normalise gain at centre frequency.
    final gain = _evalPoly(bCoeffs, math.cos(wLow)) /
        _evalPoly(aCoeffs, math.cos(wLow)).abs().clamp(_minPolyEval, double.infinity);
    final normB = bCoeffs.map((v) => v / gain).toList();

    return (b: normB, a: aCoeffs);
  }

  double _evalPoly(List<double> poly, double x) {
    var result = 0.0;
    for (var i = 0; i < poly.length; i++) {
      result += poly[i] * math.pow(x, poly.length - 1 - i);
    }
    return result;
  }

  List<double> _polyMul(List<double> a, List<double> b) {
    final result = List<double>.filled(a.length + b.length - 1, 0.0);
    for (var i = 0; i < a.length; i++) {
      for (var j = 0; j < b.length; j++) {
        result[i + j] += a[i] * b[j];
      }
    }
    return result;
  }

  /// Apply a causal IIR filter defined by [b] (numerator) and [a] (denominator).
  List<double> applyIirFilter(
    List<double> signal,
    List<double> b,
    List<double> a,
  ) {
    if (signal.isEmpty) return [];

    final n = signal.length;
    final nb = b.length;
    final na = a.length;
    final output = List<double>.filled(n, 0.0);

    // Normalise so that a[0] == 1.
    final a0 = a[0];
    final bn = b.map((v) => v / a0).toList();
    final an = a.map((v) => v / a0).toList();

    for (var i = 0; i < n; i++) {
      var y = 0.0;
      for (var j = 0; j < nb; j++) {
        if (i - j >= 0) y += bn[j] * signal[i - j];
      }
      for (var j = 1; j < na; j++) {
        if (i - j >= 0) y -= an[j] * output[i - j];
      }
      output[i] = y;
    }
    return output;
  }

  // ── Step 2: Feature Extraction ──────────────────────────────────────────

  /// Compute scalar acceleration magnitude for each sample.
  List<double> computeMagnitude(List<SensorData> data) =>
      data.map((s) => s.accelMagnitude).toList();

  /// Perform FFT on [signal] and return one-sided frequency/amplitude arrays.
  ({List<double> frequencies, List<double> amplitudes}) performFft(
    List<double> signal,
    double samplingRate,
  ) {
    final complex = _fft.forward(signal);
    final n = complex.length;
    final mags = _fft.magnitudeSpectrum(complex);
    final freqs = _fft.frequencyBins(n, samplingRate);

    // One-sided spectrum (N/2+1 bins).
    final halfN = n ~/ 2 + 1;
    return (
      frequencies: freqs.sublist(0, halfN),
      amplitudes: mags.sublist(0, halfN),
    );
  }

  /// Find the frequency with maximum amplitude in [minFreq]–[maxFreq] Hz.
  double findDominantFrequency(
    List<double> frequencies,
    List<double> amplitudes, {
    double minFreq = 3.0,
    double maxFreq = 7.0,
  }) {
    var maxAmp = -double.infinity;
    var domFreq = (minFreq + maxFreq) / 2.0;

    for (var i = 0; i < frequencies.length; i++) {
      final f = frequencies[i];
      if (f >= minFreq && f <= maxFreq && amplitudes[i] > maxAmp) {
        maxAmp = amplitudes[i];
        domFreq = f;
      }
    }
    return domFreq;
  }

  /// Area under the amplitude curve in the [minFreq]–[maxFreq] Hz band.
  double calculateTremorPower(
    List<double> frequencies,
    List<double> amplitudes, {
    double minFreq = 3.0,
    double maxFreq = 7.0,
  }) =>
      _bandPower(frequencies, amplitudes, minFreq, maxFreq);

  /// Area under the amplitude curve in the [minFreq]–[maxFreq] Hz band.
  double calculateTotalPower(
    List<double> frequencies,
    List<double> amplitudes, {
    double minFreq = 1.0,
    double maxFreq = 12.0,
  }) =>
      _bandPower(frequencies, amplitudes, minFreq, maxFreq);

  double _bandPower(
    List<double> frequencies,
    List<double> amplitudes,
    double minFreq,
    double maxFreq,
  ) {
    var power = 0.0;
    for (var i = 0; i < frequencies.length; i++) {
      if (frequencies[i] >= minFreq && frequencies[i] <= maxFreq) {
        power += amplitudes[i] * amplitudes[i];
      }
    }
    return power;
  }

  /// Ratio of [tremorPower] to [totalPower], clamped to [0, 1].
  double calculateTremorRatio(double tremorPower, double totalPower) {
    if (totalPower <= 0) return 0.0;
    return (tremorPower / totalPower).clamp(0.0, 1.0);
  }

  // ── Step 3: Classification ──────────────────────────────────────────────

  /// Map [tremorRatio] and [dominantFrequency] to a UPDRS score (0–4).
  int classifyTremor(double tremorRatio, double dominantFrequency) {
    if (tremorRatio < 0.05) return 0;
    if (tremorRatio < 0.15) return 1;
    if (tremorRatio < 0.30) return 2;
    if (tremorRatio < 0.50) return 3;
    return 4;
  }

  /// Human-readable label for a UPDRS score.
  String getUpdrsLabel(int score) {
    const labels = ['No tremor', 'Slight', 'Mild', 'Moderate', 'Severe'];
    return labels.elementAtOrNull(score) ?? 'Unknown';
  }

  /// Severity colour for a UPDRS score.
  Color getUpdrsColor(int score) {
    switch (score) {
      case 0:
        return const Color(0xFF27AE60);
      case 1:
        return const Color(0xFFF1C40F);
      case 2:
        return const Color(0xFFE67E22);
      case 3:
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF922B21);
    }
  }

  // ── Signal Quality ──────────────────────────────────────────────────────

  /// Returns `true` when the RMS amplitude is above a noise floor.
  bool isSignalQualityAdequate(List<double> signal) {
    if (signal.isEmpty) return false;
    final rms = math.sqrt(
      signal.map((v) => v * v).reduce((a, b) => a + b) / signal.length,
    );
    return rms > 0.01; // 10 mg threshold
  }

  /// Returns `true` when [data] represents at least 30 seconds.
  bool isDurationSufficient(List<SensorData> data, double samplingRate) {
    if (samplingRate <= 0) return false;
    return data.length / samplingRate >= 30.0;
  }
}
