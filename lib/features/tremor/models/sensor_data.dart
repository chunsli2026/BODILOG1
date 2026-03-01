import 'dart:math' as math;
import 'dart:typed_data';

/// Raw sensor sample from the wearable accelerometer + gyroscope.
class SensorData {
  const SensorData({
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });

  /// Millisecond epoch timestamp.
  final int timestampMs;

  /// Acceleration X-axis (m/s²).
  final double accelX;

  /// Acceleration Y-axis (m/s²).
  final double accelY;

  /// Acceleration Z-axis (m/s²).
  final double accelZ;

  /// Angular velocity X-axis (°/s).
  final double gyroX;

  /// Angular velocity Y-axis (°/s).
  final double gyroY;

  /// Angular velocity Z-axis (°/s).
  final double gyroZ;

  /// Scalar acceleration magnitude: √(x²+y²+z²).
  double get accelMagnitude =>
      math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);

  /// Scalar gyro magnitude: √(x²+y²+z²).
  double get gyroMagnitude =>
      math.sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);

  Map<String, dynamic> toMap() => {
        'timestamp_ms': timestampMs,
        'accel_x': accelX,
        'accel_y': accelY,
        'accel_z': accelZ,
        'gyro_x': gyroX,
        'gyro_y': gyroY,
        'gyro_z': gyroZ,
      };

  factory SensorData.fromMap(Map<String, dynamic> map) => SensorData(
        timestampMs: (map['timestamp_ms'] as num).toInt(),
        accelX: (map['accel_x'] as num).toDouble(),
        accelY: (map['accel_y'] as num).toDouble(),
        accelZ: (map['accel_z'] as num).toDouble(),
        gyroX: (map['gyro_x'] as num).toDouble(),
        gyroY: (map['gyro_y'] as num).toDouble(),
        gyroZ: (map['gyro_z'] as num).toDouble(),
      );

  /// Parse from a 24-byte BLE characteristic payload.
  ///
  /// Byte layout (little-endian floats):
  /// [0-3] accelX, [4-7] accelY, [8-11] accelZ,
  /// [12-15] gyroX, [16-19] gyroY, [20-23] gyroZ.
  /// (Note: Some devices may append a 4-byte sequence number at [24-27];
  /// this parser ignores any bytes beyond offset 23.)
  factory SensorData.fromBytes(List<int> bytes, int timestampMs) {
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    return SensorData(
      timestampMs: timestampMs,
      accelX: bd.getFloat32(0, Endian.little),
      accelY: bd.getFloat32(4, Endian.little),
      accelZ: bd.getFloat32(8, Endian.little),
      gyroX: bd.getFloat32(12, Endian.little),
      gyroY: bd.getFloat32(16, Endian.little),
      gyroZ: bd.getFloat32(20, Endian.little),
    );
  }
}
