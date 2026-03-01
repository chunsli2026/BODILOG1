import 'dart:convert';

/// Enumerates all supported IoT device types.
enum DeviceType {
  smartScale,
  bloodPressureMonitor,
  thermometer,
  pulseOximeter,
  wearableSensor,
}

/// Unified health data reading received from a BLE health device.
class HealthReading {
  const HealthReading({
    required this.id,
    required this.deviceType,
    required this.timestamp,
    required this.values,
    required this.unit,
    required this.deviceId,
    required this.deviceName,
    this.rawData,
  });

  /// Unique identifier for this reading (UUID string).
  final String id;

  /// The category of device that produced this reading.
  final DeviceType deviceType;

  /// When the reading was recorded.
  final DateTime timestamp;

  /// Named measurement values, e.g. `{"weight": 75.5, "bodyFat": 18.2}`.
  final Map<String, double> values;

  /// SI or display unit for the primary value, e.g. `"kg"`, `"mmHg"`, `"°C"`.
  final String unit;

  /// BLE MAC address or platform device identifier.
  final String deviceId;

  /// Human-readable name of the source device.
  final String deviceName;

  /// Raw BLE characteristic bytes as received from the device.
  final List<int>? rawData;

  // ---------------------------------------------------------------------------
  // SQLite serialisation
  // ---------------------------------------------------------------------------

  /// Converts this reading to a [Map] suitable for insertion into SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_type': deviceType.name,
      'device_id': deviceId,
      'device_name': deviceName,
      'timestamp': timestamp.toIso8601String(),
      'values_json': jsonEncode(values),
      'unit': unit,
      'raw_data_hex': rawData != null
          ? rawData!.map((b) => b.toRadixString(16).padLeft(2, '0')).join()
          : null,
    };
  }

  /// Creates a [HealthReading] from a SQLite row [map].
  factory HealthReading.fromMap(Map<String, dynamic> map) {
    final rawHex = map['raw_data_hex'] as String?;
    List<int>? rawData;
    if (rawHex != null && rawHex.isNotEmpty) {
      rawData = [
        for (var i = 0; i < rawHex.length; i += 2)
          int.parse(rawHex.substring(i, i + 2), radix: 16),
      ];
    }

    final valuesJson = map['values_json'] as String;
    final valuesDecoded = (jsonDecode(valuesJson) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toDouble()));

    return HealthReading(
      id: map['id'] as String,
      deviceType: DeviceType.values.byName(map['device_type'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      values: valuesDecoded,
      unit: map['unit'] as String,
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String,
      rawData: rawData,
    );
  }

  @override
  String toString() =>
      'HealthReading(id: $id, deviceType: $deviceType, timestamp: $timestamp)';
}
