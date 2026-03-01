import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/tremor/services/tremor_analysis_service.dart';
import 'package:bodilog/features/tremor/models/tremor_result.dart';

void main() {
  late TremorAnalysisService service;

  setUp(() {
    service = TremorAnalysisService();
  });

  // ---------------------------------------------------------------------------
  // DC offset removal
  // ---------------------------------------------------------------------------

  group('removeDcOffset', () {
    test('output has approximately zero mean', () {
      final input = List<double>.generate(100, (i) => i.toDouble() + 5.0);
      final output = service.removeDcOffset(input);
      final mean = output.reduce((a, b) => a + b) / output.length;
      expect(mean.abs(), lessThan(1e-10));
    });

    test('known input: signal [1, 2, 3] → [-1, 0, 1]', () {
      final output = service.removeDcOffset([1.0, 2.0, 3.0]);
      expect(output[0], closeTo(-1.0, 1e-10));
      expect(output[1], closeTo(0.0, 1e-10));
      expect(output[2], closeTo(1.0, 1e-10));
    });

    test('empty input returns empty list', () {
      expect(service.removeDcOffset([]), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Bandpass filter
  // ---------------------------------------------------------------------------

  group('bandpassFilter', () {
    const double fs = 50.0;
    const int nSamples = 2048;

    /// Generates a pure sine wave at [freqHz] with [n] samples at [fs] Hz.
    List<double> sineWave(double freqHz, {int n = nSamples}) =>
        List<double>.generate(
            n, (i) => sin(2.0 * pi * freqHz * i / fs));

    test('5 Hz sine wave (in-band) passes through with significant energy', () {
      final input = sineWave(5.0);
      final output = service.bandpassFilter(input, fs);

      // Skip transient at the start; measure RMS over the second half.
      final half = output.length ~/ 2;
      final rms = sqrt(output
              .sublist(half)
              .map((v) => v * v)
              .reduce((a, b) => a + b) /
          (output.length - half));

      // A 5 Hz sine (amplitude 1) should survive mostly intact (RMS ≈ 0.7).
      expect(rms, greaterThan(0.3),
          reason: '5 Hz is in-band; RMS should be substantial.');
    });

    test('0.3 Hz sine wave (below band) is heavily attenuated', () {
      final input = sineWave(0.3);
      final output = service.bandpassFilter(input, fs);

      final half = output.length ~/ 2;
      final rms = sqrt(output
              .sublist(half)
              .map((v) => v * v)
              .reduce((a, b) => a + b) /
          (output.length - half));

      expect(rms, lessThan(0.1),
          reason: '0.3 Hz is below the 1 Hz high-pass; should be attenuated.');
    });

    test('empty input returns empty list', () {
      expect(service.bandpassFilter([], fs), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // FFT
  // ---------------------------------------------------------------------------

  group('computeFFT', () {
    const double fs = 50.0;
    const int n = 512;

    test('pure 5 Hz sine → dominant frequency near 5 Hz', () {
      final signal = List<double>.generate(
          n, (i) => sin(2.0 * pi * 5.0 * i / fs));
      final fft = service.computeFFT(signal, fs);

      final dominant = service.findDominantFrequency(fft,
          minFreq: 0.0, maxFreq: fs / 2);
      expect(dominant, closeTo(5.0, 1.0),
          reason: 'Dominant frequency should be near 5 Hz.');
    });

    test('composite 3 Hz + 7 Hz signal has peaks near both frequencies', () {
      final signal = List<double>.generate(
          n, (i) => sin(2.0 * pi * 3.0 * i / fs) +
              sin(2.0 * pi * 7.0 * i / fs));
      final fft = service.computeFFT(signal, fs);

      final amp3 = fft.getAmplitudeAt(3.0);
      final amp7 = fft.getAmplitudeAt(7.0);
      final ampNoise = fft.getAmplitudeAt(15.0);

      expect(amp3, greaterThan(ampNoise * 2),
          reason: 'Should have a peak near 3 Hz.');
      expect(amp7, greaterThan(ampNoise * 2),
          reason: 'Should have a peak near 7 Hz.');
    });

    test('non-power-of-2 input is zero-padded and produces valid output', () {
      // 300 samples — not a power of 2.
      final signal =
          List<double>.generate(300, (i) => sin(2.0 * pi * 5.0 * i / fs));
      final fft = service.computeFFT(signal, fs);

      expect(fft.frequencies, isNotEmpty);
      expect(fft.amplitudes.length, equals(fft.frequencies.length));
    });

    test('empty input returns empty FftResult', () {
      final fft = service.computeFFT([], fs);
      expect(fft.frequencies, isEmpty);
      expect(fft.amplitudes, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // UPDRS classification
  // ---------------------------------------------------------------------------

  group('classifyTremor', () {
    test('tremorRatio = 0.01 → score 0', () {
      expect(service.classifyTremor(0.01), equals(0));
    });

    test('tremorRatio = 0.10 → score 1', () {
      expect(service.classifyTremor(0.10), equals(1));
    });

    test('tremorRatio = 0.20 → score 2', () {
      expect(service.classifyTremor(0.20), equals(2));
    });

    test('tremorRatio = 0.40 → score 3', () {
      expect(service.classifyTremor(0.40), equals(3));
    });

    test('tremorRatio = 0.60 → score 4', () {
      expect(service.classifyTremor(0.60), equals(4));
    });

    test('boundary: exactly 0.05 → score 1 (not 0)', () {
      expect(service.classifyTremor(0.05), equals(1));
    });

    test('boundary: exactly 0.15 → score 2 (not 1)', () {
      expect(service.classifyTremor(0.15), equals(2));
    });

    test('boundary: exactly 0.30 → score 3 (not 2)', () {
      expect(service.classifyTremor(0.30), equals(3));
    });

    test('boundary: exactly 0.50 → score 4 (not 3)', () {
      expect(service.classifyTremor(0.50), equals(4));
    });
  });

  // ---------------------------------------------------------------------------
  // Power calculations
  // ---------------------------------------------------------------------------

  group('power calculations', () {
    test('tremor power ≤ total power for a typical signal', () {
      const double fs = 50.0;
      final signal = List<double>.generate(
          512, (i) => sin(2.0 * pi * 5.0 * i / fs));
      final fft = service.computeFFT(signal, fs);

      final tremor = service.calculateTremorPower(fft);
      final total = service.calculateTotalPower(fft);

      expect(tremor, lessThanOrEqualTo(total));
    });

    test('pure 5 Hz signal: tremor band contains most of the total power', () {
      const double fs = 50.0;
      final signal = List<double>.generate(
          1024, (i) => sin(2.0 * pi * 5.0 * i / fs));
      final detrended = service.removeDcOffset(signal);
      final fft = service.computeFFT(detrended, fs);

      final tremor = service.calculateTremorPower(fft);
      final total = service.calculateTotalPower(fft);

      // 5 Hz is in the 3–7 Hz tremor band → ratio should be high.
      expect(total > 0 ? tremor / total : 0.0, greaterThan(0.5));
    });
  });

  // ---------------------------------------------------------------------------
  // FftResult helpers
  // ---------------------------------------------------------------------------

  group('FftResult.getRange', () {
    test('returns only bins within the specified range', () {
      const fft = FftResult(
        frequencies: [1.0, 2.0, 5.0, 8.0, 15.0],
        amplitudes: [0.1, 0.2, 0.8, 0.3, 0.1],
      );

      final range = fft.getRange(3.0, 7.0);
      expect(range.map((fa) => fa.frequency).toList(),
          equals([5.0]));
    });
  });
}
