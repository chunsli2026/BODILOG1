import 'dart:math';
import 'dart:typed_data';

/// Single sensor data point captured at a specific moment in time.
class SensorDataPoint {
  const SensorDataPoint({
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });

  /// Milliseconds since recording start.
  final int timestampMs;

  /// Acceleration X axis (m/s²).
  final double accelX;

  /// Acceleration Y axis (m/s²).
  final double accelY;

  /// Acceleration Z axis (m/s²).
  final double accelZ;

  /// Angular velocity X axis (°/s).
  final double gyroX;

  /// Angular velocity Y axis (°/s).
  final double gyroY;

  /// Angular velocity Z axis (°/s).
  final double gyroZ;

  /// Compute acceleration magnitude: √(x² + y² + z²).
  double get accelMagnitude =>
      sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);

  /// Compute gyroscope magnitude: √(x² + y² + z²).
  double get gyroMagnitude =>
      sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);

  /// Converts this data point to a [Map] suitable for SQLite insertion.
  Map<String, dynamic> toMap() {
    return {
      'timestamp_ms': timestampMs,
      'accel_x': accelX,
      'accel_y': accelY,
      'accel_z': accelZ,
      'gyro_x': gyroX,
      'gyro_y': gyroY,
      'gyro_z': gyroZ,
    };
  }

  /// Creates a [SensorDataPoint] from a SQLite row [map].
  factory SensorDataPoint.fromMap(Map<String, dynamic> map) {
    return SensorDataPoint(
      timestampMs: map['timestamp_ms'] as int,
      accelX: (map['accel_x'] as num).toDouble(),
      accelY: (map['accel_y'] as num).toDouble(),
      accelZ: (map['accel_z'] as num).toDouble(),
      gyroX: (map['gyro_x'] as num).toDouble(),
      gyroY: (map['gyro_y'] as num).toDouble(),
      gyroZ: (map['gyro_z'] as num).toDouble(),
    );
  }

  /// Parses a [SensorDataPoint] from raw BLE characteristic bytes.
  ///
  /// Expected byte layout (6 × float32 little-endian, 24 bytes total):
  /// - Bytes 0–3:   accel_x
  /// - Bytes 4–7:   accel_y
  /// - Bytes 8–11:  accel_z
  /// - Bytes 12–15: gyro_x
  /// - Bytes 16–19: gyro_y
  /// - Bytes 20–23: gyro_z
  factory SensorDataPoint.fromBleBytes(List<int> bytes, int timestampMs) {
    if (bytes.length < 24) {
      throw ArgumentError(
          'Expected at least 24 bytes, got ${bytes.length}');
    }
    return SensorDataPoint(
      timestampMs: timestampMs,
      accelX: _bytesToFloat32(bytes, 0),
      accelY: _bytesToFloat32(bytes, 4),
      accelZ: _bytesToFloat32(bytes, 8),
      gyroX: _bytesToFloat32(bytes, 12),
      gyroY: _bytesToFloat32(bytes, 16),
      gyroZ: _bytesToFloat32(bytes, 20),
    );
  }

  static double _bytesToFloat32(List<int> bytes, int offset) {
    final bd = ByteData(4);
    for (var i = 0; i < 4; i++) {
      bd.setUint8(i, bytes[offset + i] & 0xFF);
    }
    return bd.getFloat32(0, Endian.little);
  }
}

/// A recording buffer that accumulates [SensorDataPoint]s for analysis.
///
/// Acts as a ring buffer capped at [maxCapacity] entries; oldest data
/// is dropped when the buffer is full.
class SensorDataBuffer {
  SensorDataBuffer({
    required this.samplingRateHz,
    required this.recordingStart,
  }) : data = [];

  /// All currently buffered data points.
  final List<SensorDataPoint> data;

  /// Nominal sampling rate of the connected sensor in Hz.
  final double samplingRateHz;

  /// UTC timestamp when the recording was started.
  final DateTime recordingStart;

  /// Maximum number of data points (100 Hz × 60 s).
  static const int maxCapacity = 6000;

  /// Duration of the currently buffered data in seconds.
  double get durationSeconds =>
      samplingRateHz > 0 ? data.length / samplingRateHz : 0.0;

  /// Returns `true` when at least 30 seconds of data have been buffered.
  bool get hasMinimumData => durationSeconds >= 30.0;

  /// Returns `true` when at least 60 seconds of data have been buffered.
  bool get hasRecommendedData => durationSeconds >= 60.0;

  /// Returns the acceleration magnitude time series.
  List<double> get accelMagnitudes =>
      data.map((d) => d.accelMagnitude).toList();

  /// Appends [point] to the buffer, dropping the oldest entry when full.
  void addDataPoint(SensorDataPoint point) {
    if (data.length >= maxCapacity) {
      data.removeAt(0);
    }
    data.add(point);
  }

  /// Removes all buffered data points.
  void clear() => data.clear();
}
