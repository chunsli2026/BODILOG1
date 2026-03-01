import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/tremor/models/sensor_data.dart';
import 'package:bodilog/features/tremor/models/tremor_result.dart';
import 'package:bodilog/features/tremor/models/tremor_session.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SensorDataPoint
  // ---------------------------------------------------------------------------

  group('SensorDataPoint', () {
    const point = SensorDataPoint(
      timestampMs: 1000,
      accelX: 1.0,
      accelY: 2.0,
      accelZ: 2.0,
      gyroX: 3.0,
      gyroY: 4.0,
      gyroZ: 0.0,
    );

    test('toMap() produces correct keys and values', () {
      final map = point.toMap();

      expect(map['timestamp_ms'], equals(1000));
      expect(map['accel_x'], equals(1.0));
      expect(map['accel_y'], equals(2.0));
      expect(map['accel_z'], equals(2.0));
      expect(map['gyro_x'], equals(3.0));
      expect(map['gyro_y'], equals(4.0));
      expect(map['gyro_z'], equals(0.0));
    });

    test('fromMap(toMap()) round-trip preserves all fields', () {
      final map = point.toMap();
      final restored = SensorDataPoint.fromMap(map);

      expect(restored.timestampMs, equals(point.timestampMs));
      expect(restored.accelX, equals(point.accelX));
      expect(restored.accelY, equals(point.accelY));
      expect(restored.accelZ, equals(point.accelZ));
      expect(restored.gyroX, equals(point.gyroX));
      expect(restored.gyroY, equals(point.gyroY));
      expect(restored.gyroZ, equals(point.gyroZ));
    });

    test('accelMagnitude = √(1² + 2² + 2²) = 3', () {
      expect(point.accelMagnitude, closeTo(3.0, 1e-10));
    });

    test('gyroMagnitude = √(3² + 4² + 0²) = 5', () {
      expect(point.gyroMagnitude, closeTo(5.0, 1e-10));
    });

    test('accelMagnitude of zero vector = 0', () {
      const zero = SensorDataPoint(
        timestampMs: 0,
        accelX: 0,
        accelY: 0,
        accelZ: 0,
        gyroX: 0,
        gyroY: 0,
        gyroZ: 0,
      );
      expect(zero.accelMagnitude, equals(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // SensorDataBuffer
  // ---------------------------------------------------------------------------

  group('SensorDataBuffer', () {
    SensorDataBuffer makeBuffer({double fs = 50.0, int count = 0}) {
      final buf = SensorDataBuffer(
        samplingRateHz: fs,
        recordingStart: DateTime.utc(2026, 1, 1),
      );
      for (var i = 0; i < count; i++) {
        buf.addDataPoint(SensorDataPoint(
          timestampMs: i * 20,
          accelX: 0,
          accelY: 0,
          accelZ: 1,
          gyroX: 0,
          gyroY: 0,
          gyroZ: 0,
        ));
      }
      return buf;
    }

    test('hasMinimumData is false when < 30 seconds of data', () {
      // 50 Hz × 29 s = 1450 samples
      expect(makeBuffer(fs: 50.0, count: 1450).hasMinimumData, isFalse);
    });

    test('hasMinimumData is true at exactly 30 seconds (1500 samples @ 50 Hz)',
        () {
      expect(makeBuffer(fs: 50.0, count: 1500).hasMinimumData, isTrue);
    });

    test('hasRecommendedData is false before 60 seconds', () {
      expect(makeBuffer(fs: 50.0, count: 2999).hasRecommendedData, isFalse);
    });

    test('hasRecommendedData is true at exactly 60 seconds', () {
      expect(makeBuffer(fs: 50.0, count: 3000).hasRecommendedData, isTrue);
    });

    test('ring buffer drops oldest entry when full', () {
      const capacity = SensorDataBuffer.maxCapacity;
      final buf = makeBuffer(fs: 100.0, count: capacity);

      // All entries should be present.
      expect(buf.data.length, equals(capacity));

      // Add one more point — should drop the first.
      const newPoint = SensorDataPoint(
        timestampMs: 999999,
        accelX: 99,
        accelY: 99,
        accelZ: 99,
        gyroX: 0,
        gyroY: 0,
        gyroZ: 0,
      );
      buf.addDataPoint(newPoint);

      expect(buf.data.length, equals(capacity));
      expect(buf.data.last.timestampMs, equals(999999));
      // First entry (timestampMs = 0) has been dropped.
      expect(buf.data.first.timestampMs, isNot(equals(0)));
    });

    test('clear() removes all data points', () {
      final buf = makeBuffer(count: 100);
      buf.clear();
      expect(buf.data, isEmpty);
    });

    test('accelMagnitudes returns magnitude for each data point', () {
      final buf = makeBuffer(count: 3);
      // Each point has accelZ = 1, rest = 0 → magnitude = 1.
      for (final m in buf.accelMagnitudes) {
        expect(m, closeTo(1.0, 1e-10));
      }
    });

    test('durationSeconds is correct', () {
      final buf = makeBuffer(fs: 50.0, count: 250);
      expect(buf.durationSeconds, closeTo(5.0, 1e-10));
    });
  });

  // ---------------------------------------------------------------------------
  // TremorResult
  // ---------------------------------------------------------------------------

  group('TremorResult', () {
    const fft = FftResult(frequencies: [1.0, 5.0], amplitudes: [0.1, 0.8]);

    TremorResult makeResult(int score) {
      const labels = ['No tremor', 'Slight', 'Mild', 'Moderate', 'Severe'];
      return TremorResult(
        updrsScore: score,
        updrsLabel: labels[score],
        dominantFrequencyHz: 5.0,
        tremorRatio: 0.2,
        tremorPower: 0.5,
        totalPower: 2.5,
        fftResult: fft,
        recordingDuration: const Duration(seconds: 60),
        samplingRateHz: 50.0,
      );
    }

    test('scoreColor for 0 is green', () {
      expect(makeResult(0).scoreColor, equals(const Color(0xFF27AE60)));
    });

    test('scoreColor for 1 is light green', () {
      expect(makeResult(1).scoreColor, equals(const Color(0xFF2ECC71)));
    });

    test('scoreColor for 2 is amber', () {
      expect(makeResult(2).scoreColor, equals(const Color(0xFFF39C12)));
    });

    test('scoreColor for 3 is orange', () {
      expect(makeResult(3).scoreColor, equals(const Color(0xFFE67E22)));
    });

    test('scoreColor for 4 is red', () {
      expect(makeResult(4).scoreColor, equals(const Color(0xFFE74C3C)));
    });

    test('isSignificant is false for scores 0 and 1', () {
      expect(makeResult(0).isSignificant, isFalse);
      expect(makeResult(1).isSignificant, isFalse);
    });

    test('isSignificant is true for scores 2, 3, 4', () {
      expect(makeResult(2).isSignificant, isTrue);
      expect(makeResult(3).isSignificant, isTrue);
      expect(makeResult(4).isSignificant, isTrue);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final r = makeResult(2);
      final map = r.toMap();
      final restored = TremorResult.fromMap(map);

      expect(restored.updrsScore, equals(r.updrsScore));
      expect(restored.updrsLabel, equals(r.updrsLabel));
      expect(restored.dominantFrequencyHz,
          closeTo(r.dominantFrequencyHz, 1e-10));
      expect(restored.tremorRatio, closeTo(r.tremorRatio, 1e-10));
      expect(restored.tremorPower, closeTo(r.tremorPower, 1e-10));
      expect(restored.totalPower, closeTo(r.totalPower, 1e-10));
      expect(restored.samplingRateHz, closeTo(r.samplingRateHz, 1e-10));
      expect(restored.recordingDuration, equals(r.recordingDuration));
    });
  });

  // ---------------------------------------------------------------------------
  // TremorSession
  // ---------------------------------------------------------------------------

  group('TremorSession', () {
    const fft = FftResult(frequencies: [3.0, 5.0], amplitudes: [0.3, 0.9]);
    final result = TremorResult(
      updrsScore: 1,
      updrsLabel: 'Slight',
      dominantFrequencyHz: 5.0,
      tremorRatio: 0.10,
      tremorPower: 0.1,
      totalPower: 1.0,
      fftResult: fft,
      recordingDuration: const Duration(seconds: 45),
      samplingRateHz: 50.0,
    );

    final session = TremorSession(
      id: 'session-abc-123',
      deviceId: 'AA:BB:CC:DD:EE:FF',
      timestamp: DateTime.utc(2026, 3, 1, 10, 0, 0),
      durationSeconds: 45,
      samplingRateHz: 50.0,
      result: result,
    );

    test('toMap() produces correct keys', () {
      final map = session.toMap();

      expect(map['id'], equals('session-abc-123'));
      expect(map['device_id'], equals('AA:BB:CC:DD:EE:FF'));
      expect(map['timestamp'], equals('2026-03-01T10:00:00.000Z'));
      expect(map['duration_seconds'], equals(45));
      expect(map['sample_rate_hz'], equals(50.0));
      expect(map['updrs_score'], equals(1));
      expect(map['updrs_label'], equals('Slight'));
    });

    test('fromMap(toMap()) round-trip preserves all fields', () {
      final map = session.toMap();
      final restored = TremorSession.fromMap(map);

      expect(restored.id, equals(session.id));
      expect(restored.deviceId, equals(session.deviceId));
      expect(restored.timestamp, equals(session.timestamp));
      expect(restored.durationSeconds, equals(session.durationSeconds));
      expect(restored.samplingRateHz,
          closeTo(session.samplingRateHz, 1e-10));
      expect(restored.result.updrsScore,
          equals(session.result.updrsScore));
      expect(restored.result.updrsLabel,
          equals(session.result.updrsLabel));
    });
  });
}
