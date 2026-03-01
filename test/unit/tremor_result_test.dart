import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/tremor/models/sensor_data.dart';
import 'package:bodilog/features/tremor/models/tremor_result.dart';
import 'package:bodilog/features/tremor/models/tremor_session.dart';

void main() {
  group('SensorData', () {
    test('accelMagnitude is correct', () {
      const s = SensorData(
        timestampMs: 0,
        accelX: 3.0,
        accelY: 4.0,
        accelZ: 0.0,
        gyroX: 0,
        gyroY: 0,
        gyroZ: 0,
      );
      expect(s.accelMagnitude, closeTo(5.0, 1e-9));
    });

    test('gyroMagnitude is correct', () {
      const s = SensorData(
        timestampMs: 0,
        accelX: 0,
        accelY: 0,
        accelZ: 0,
        gyroX: 0.0,
        gyroY: 3.0,
        gyroZ: 4.0,
      );
      expect(s.gyroMagnitude, closeTo(5.0, 1e-9));
    });

    test('toMap / fromMap roundtrip', () {
      const s = SensorData(
        timestampMs: 12345,
        accelX: 1.1,
        accelY: 2.2,
        accelZ: 3.3,
        gyroX: 4.4,
        gyroY: 5.5,
        gyroZ: 6.6,
      );
      final map = s.toMap();
      final restored = SensorData.fromMap(map);
      expect(restored.timestampMs, equals(s.timestampMs));
      expect(restored.accelX, closeTo(s.accelX, 1e-6));
      expect(restored.gyroZ, closeTo(s.gyroZ, 1e-6));
    });

    test('fromBytes parses 24-byte payload', () {
      // Build a 24-byte buffer with known float32 values.
      final bd = ByteData(24);
      bd.setFloat32(0, 1.0, Endian.little);
      bd.setFloat32(4, 2.0, Endian.little);
      bd.setFloat32(8, 3.0, Endian.little);
      bd.setFloat32(12, 4.0, Endian.little);
      bd.setFloat32(16, 5.0, Endian.little);
      bd.setFloat32(20, 6.0, Endian.little);
      final bytes = bd.buffer.asUint8List();

      final s = SensorData.fromBytes(bytes, 999);
      expect(s.timestampMs, equals(999));
      expect(s.accelX, closeTo(1.0, 1e-4));
      expect(s.accelY, closeTo(2.0, 1e-4));
      expect(s.accelZ, closeTo(3.0, 1e-4));
      expect(s.gyroX, closeTo(4.0, 1e-4));
      expect(s.gyroY, closeTo(5.0, 1e-4));
      expect(s.gyroZ, closeTo(6.0, 1e-4));
    });
  });

  group('TremorResult', () {
    TremorResult makeResult(int score) => TremorResult(
          updrsScore: score,
          updrsLabel: 'Test',
          dominantFrequency: 5.0,
          tremorRatio: 0.2,
          tremorPower: 10.0,
          totalPower: 50.0,
          fftFrequencies: [1.0, 2.0],
          fftAmplitudes: [0.5, 1.0],
          samplingRate: 100.0,
          durationSeconds: 60,
          analyzedAt: DateTime(2025, 1, 1),
        );

    test('toMap / fromMap roundtrip', () {
      final r = makeResult(2);
      final map = r.toMap();
      final restored = TremorResult.fromMap(map);
      expect(restored.updrsScore, equals(2));
      expect(restored.dominantFrequency, closeTo(5.0, 1e-9));
      expect(restored.fftFrequencies.length, equals(2));
      expect(restored.analyzedAt, equals(DateTime(2025, 1, 1)));
    });

    test('severityColor returns different colours per score', () {
      final colors =
          List.generate(5, (i) => makeResult(i).severityColor);
      // All five should be distinct.
      expect(colors.toSet().length, equals(5));
    });
  });

  group('TremorSession', () {
    test('toMap / fromMap roundtrip', () {
      final s = TremorSession(
        id: 'abc',
        deviceId: 'dev-1',
        timestamp: DateTime(2025, 6, 15, 10, 30),
        durationSeconds: 45,
        samplingRate: 50.0,
        updrsScore: 1,
        dominantFrequency: 4.8,
        tremorRatio: 0.12,
        tremorPower: 3.0,
        totalPower: 25.0,
      );
      final map = s.toMap();
      final restored = TremorSession.fromMap(map);
      expect(restored.id, equals('abc'));
      expect(restored.durationSeconds, equals(45));
      expect(restored.updrsScore, equals(1));
      expect(restored.dominantFrequency, closeTo(4.8, 1e-9));
      expect(restored.isAnalyzed, isFalse); // no TremorResult attached
    });

    test('isAnalyzed is false without result', () {
      final s = TremorSession(
        id: 'x',
        deviceId: 'd',
        timestamp: DateTime.now(),
        durationSeconds: 0,
        samplingRate: 50,
      );
      expect(s.isAnalyzed, isFalse);
    });
  });
}
