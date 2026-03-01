import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/tremor/models/sensor_data.dart';
import 'package:bodilog/features/tremor/services/tremor_analysis_service.dart';

void main() {
  late TremorAnalysisService service;
  late FFT fft;

  setUp(() {
    service = TremorAnalysisService();
    fft = const FFT();
  });

  // ── FFT tests ──────────────────────────────────────────────────────────────

  group('FFT', () {
    test('dominant frequency of a 5 Hz sine at 100 Hz sampling rate is ~5 Hz',
        () {
      const fs = 100.0;
      const freqHz = 5.0;
      const n = 512;
      final signal = List.generate(
        n,
        (i) => math.sin(2 * math.pi * freqHz * i / fs),
      );

      final complex = fft.forward(signal);
      final mags = fft.magnitudeSpectrum(complex);
      final paddedN = fft.nextPowerOfTwo(n); // == 512
      final freqs = fft.frequencyBins(paddedN, fs);

      // Find peak in 0–50 Hz.
      var maxAmp = 0.0;
      var peakFreq = 0.0;
      for (var i = 0; i < freqs.length; i++) {
        if (freqs[i] <= fs / 2 && mags[i] > maxAmp) {
          maxAmp = mags[i];
          peakFreq = freqs[i];
        }
      }

      expect(peakFreq, closeTo(freqHz, 1.0));
    });

    test('zero-padding pads to next power of two', () {
      final s = List.generate(100, (i) => i.toDouble());
      final padded = fft.zeroPad(s);
      expect(padded.length, equals(128));
      expect(fft.isPowerOfTwo(padded.length), isTrue);
    });

    test('frequency bins have correct resolution', () {
      const fs = 100.0;
      const n = 256;
      final bins = fft.frequencyBins(n, fs);
      expect(bins.first, closeTo(0.0, 1e-9));
      expect(bins[1], closeTo(fs / n, 1e-9));
      expect(bins.length, equals(n ~/ 2 + 1));
    });

    test('isPowerOfTwo', () {
      expect(fft.isPowerOfTwo(1), isTrue);
      expect(fft.isPowerOfTwo(64), isTrue);
      expect(fft.isPowerOfTwo(100), isFalse);
    });

    test('nextPowerOfTwo', () {
      expect(fft.nextPowerOfTwo(1), equals(1));
      expect(fft.nextPowerOfTwo(100), equals(128));
      expect(fft.nextPowerOfTwo(128), equals(128));
      expect(fft.nextPowerOfTwo(129), equals(256));
    });
  });

  // ── Bandpass filter tests ──────────────────────────────────────────────────

  group('bandpass filter', () {
    test('DC component is reduced after filtering', () {
      const fs = 100.0;
      // DC signal (constant value 5.0).
      final dc = List<double>.filled(200, 5.0);
      final filtered = service.bandpassFilter(dc, fs);
      final rms = math.sqrt(
        filtered.map((v) => v * v).reduce((a, b) => a + b) / filtered.length,
      );
      // After filtering DC should be heavily attenuated.
      expect(rms, lessThan(1.0));
    });

    test('Butterworth coefficients are non-empty', () {
      final (:b, :a) =
          service.butterworthCoefficients(100.0, 1.0, 12.0, 4);
      expect(b, isNotEmpty);
      expect(a, isNotEmpty);
    });
  });

  // ── Tremor classification tests ────────────────────────────────────────────

  group('classifyTremor', () {
    test('UPDRS 0 for ratio < 0.05', () {
      expect(service.classifyTremor(0.04, 5.0), equals(0));
    });

    test('UPDRS 1 for ratio 0.05–0.15', () {
      expect(service.classifyTremor(0.10, 5.0), equals(1));
    });

    test('UPDRS 2 for ratio 0.15–0.30', () {
      expect(service.classifyTremor(0.20, 5.0), equals(2));
    });

    test('UPDRS 3 for ratio 0.30–0.50', () {
      expect(service.classifyTremor(0.40, 5.0), equals(3));
    });

    test('UPDRS 4 for ratio > 0.50', () {
      expect(service.classifyTremor(0.60, 5.0), equals(4));
    });
  });

  // ── Signal quality ─────────────────────────────────────────────────────────

  group('signal quality', () {
    test('flat signal fails quality check', () {
      final flat = List<double>.filled(100, 0.001);
      expect(service.isSignalQualityAdequate(flat), isFalse);
    });

    test('valid tremor signal passes quality check', () {
      const fs = 100.0;
      final signal = List.generate(
        512,
        (i) => 0.5 * math.sin(2 * math.pi * 5.0 * i / fs),
      );
      expect(service.isSignalQualityAdequate(signal), isTrue);
    });
  });

  // ── Duration validation ────────────────────────────────────────────────────

  group('isDurationSufficient', () {
    SensorData dummySample() => const SensorData(
          timestampMs: 0,
          accelX: 0,
          accelY: 0,
          accelZ: 9.81,
          gyroX: 0,
          gyroY: 0,
          gyroZ: 0,
        );

    test('< 30 seconds returns false', () {
      final data = List.generate(1000, (_) => dummySample()); // 20 s at 50 Hz
      expect(service.isDurationSufficient(data, 50.0), isFalse);
    });

    test('>= 30 seconds returns true', () {
      final data = List.generate(3000, (_) => dummySample()); // 60 s at 50 Hz
      expect(service.isDurationSufficient(data, 50.0), isTrue);
    });
  });

  // ── Integration test ───────────────────────────────────────────────────────

  group('analyzeRecording integration', () {
    test('synthetic 5 Hz tremor signal yields UPDRS score and ~5 Hz dominant freq',
        () async {
      const fs = 100.0;
      const durationSecs = 60;
      const n = (fs * durationSecs).toInt();
      const tremorFreq = 5.0;

      final rng = math.Random(42);
      final data = List.generate(n, (i) {
        final t = i / fs;
        final tremor = 0.5 * math.sin(2 * math.pi * tremorFreq * t);
        final noise = (rng.nextDouble() - 0.5) * 0.05;
        return SensorData(
          timestampMs: (t * 1000).toInt(),
          accelX: tremor + noise,
          accelY: noise,
          accelZ: 9.81 + noise * 0.1,
          gyroX: noise,
          gyroY: noise,
          gyroZ: noise,
        );
      });

      final result = await service.analyzeRecording(data, fs);

      expect(result.isSuccess, isTrue);
      final r = (result as dynamic).data;
      expect(r.updrsScore, greaterThanOrEqualTo(0));
      expect(r.updrsScore, lessThanOrEqualTo(4));
      expect(r.dominantFrequency, closeTo(tremorFreq, 1.5));
    });
  });
}
