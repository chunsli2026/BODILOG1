import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/shared/models/health_reading.dart';

void main() {
  group('HealthReading serialisation', () {
    final reading = HealthReading(
      id: 'test-id-123',
      deviceType: DeviceType.smartScale,
      timestamp: DateTime.utc(2026, 3, 1, 12, 0, 0),
      values: {'weight': 75.5, 'bodyFat': 18.2},
      unit: 'kg',
      deviceId: 'AA:BB:CC:DD:EE:FF',
      deviceName: 'Smart Scale Pro',
      rawData: [0x01, 0x02, 0x03],
    );

    test('toMap() produces correct keys and values', () {
      final map = reading.toMap();

      expect(map['id'], equals('test-id-123'));
      expect(map['device_type'], equals('smartScale'));
      expect(map['device_id'], equals('AA:BB:CC:DD:EE:FF'));
      expect(map['device_name'], equals('Smart Scale Pro'));
      expect(map['timestamp'], equals('2026-03-01T12:00:00.000Z'));
      expect(map['unit'], equals('kg'));
      expect(map['raw_data_hex'], equals('010203'));
    });

    test('fromMap(toMap()) round-trip preserves all fields', () {
      final map = reading.toMap();
      final restored = HealthReading.fromMap(map);

      expect(restored.id, equals(reading.id));
      expect(restored.deviceType, equals(reading.deviceType));
      expect(restored.timestamp, equals(reading.timestamp));
      expect(restored.values, equals(reading.values));
      expect(restored.unit, equals(reading.unit));
      expect(restored.deviceId, equals(reading.deviceId));
      expect(restored.deviceName, equals(reading.deviceName));
      expect(restored.rawData, equals(reading.rawData));
    });

    test('null rawData is handled correctly', () {
      final readingNoRaw = HealthReading(
        id: 'no-raw',
        deviceType: DeviceType.thermometer,
        timestamp: DateTime.utc(2026, 1, 1),
        values: {'temperature': 36.6},
        unit: '°C',
        deviceId: 'device-001',
        deviceName: 'Thermometer',
      );

      final map = readingNoRaw.toMap();
      expect(map['raw_data_hex'], isNull);

      final restored = HealthReading.fromMap(map);
      expect(restored.rawData, isNull);
    });
  });
}
