import 'dart:async';
import 'dart:math' as math;

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../models/sensor_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ring buffer
// ─────────────────────────────────────────────────────────────────────────────

/// A fixed-capacity circular buffer.
class RingBuffer<T> {
  RingBuffer({required this.capacity}) : _data = [];

  /// Maximum number of elements.
  final int capacity;

  final List<T> _data;

  /// All buffered items in insertion order.
  List<T> get data => List.unmodifiable(_data);

  /// Append [item], discarding the oldest entry when full.
  void add(T item) {
    if (_data.length >= capacity) _data.removeAt(0);
    _data.add(item);
  }

  /// Remove all elements.
  void clear() => _data.clear();

  /// `true` when the buffer holds [capacity] elements.
  bool get isFull => _data.length >= capacity;

  /// Current element count.
  int get length => _data.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Wearable Sensor Service
// ─────────────────────────────────────────────────────────────────────────────

/// Manages BLE data acquisition from the wearable IMU sensor.
///
/// BLE service UUID : `0000fff0-0000-1000-8000-00805f9b34fb`
/// Accelerometer characteristic : `0000fff1-0000-1000-8000-00805f9b34fb`
/// Gyroscope characteristic     : `0000fff2-0000-1000-8000-00805f9b34fb`
///
/// Expected sampling rate ≥ 50 Hz (50–100 Hz recommended).
class WearableSensorService {
  WearableSensorService()
      : dataBuffer = RingBuffer<SensorData>(
          capacity: 100 * 60, // 60 s at 100 Hz
        );

  /// UUID of the custom IMU BLE service.
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';

  /// UUID of the accelerometer characteristic.
  static const String accelCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';

  /// UUID of the gyroscope characteristic.
  static const String gyroCharUuid = '0000fff2-0000-1000-8000-00805f9b34fb';

  /// Ring buffer holding up to 60 seconds of sensor samples.
  final RingBuffer<SensorData> dataBuffer;

  StreamController<Result<SensorData>>? _controller;
  Timer? _simulationTimer;
  String? _connectedDeviceId;
  bool _streaming = false;
  final double _simulatedSamplingRate = 50.0;
  final math.Random _rng = math.Random();

  /// `true` while a data stream is active.
  bool get isStreaming => _streaming;

  /// The connected device ID, or `null` when not connected.
  String? get connectedDeviceId => _connectedDeviceId;

  /// Connect to [deviceId] and return a stream of [SensorData].
  ///
  /// In this implementation the connection is simulated with a 50 Hz timer
  /// that emits synthetic IMU data.  A real implementation would use
  /// [flutter_blue_plus] to subscribe to BLE notifications.
  Stream<Result<SensorData>> startDataStream(String deviceId) {
    if (_streaming) {
      return Stream.value(
        const AppError(BluetoothFailure('Already streaming data.')),
      );
    }

    _connectedDeviceId = deviceId;
    _streaming = true;
    _controller = StreamController<Result<SensorData>>.broadcast();

    // Simulate 50 Hz sensor data.
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => _emitSimulatedSample(),
    );

    return _controller!.stream;
  }

  void _emitSimulatedSample() {
    if (_controller == null || _controller!.isClosed) return;

    final rng = _rng;
    const freq = 5.0; // 5 Hz tremor
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final tremorComponent = 0.3 * math.sin(2 * math.pi * freq * t);
    final noise = (rng.nextDouble() - 0.5) * 0.05;

    final sample = SensorData(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      accelX: tremorComponent + noise,
      accelY: noise * 0.5,
      accelZ: 9.81 + noise * 0.2, // gravity
      gyroX: noise * 10,
      gyroY: noise * 10,
      gyroZ: noise * 10,
    );

    dataBuffer.add(sample);
    _controller!.add(Success(sample));
  }

  /// Stop the data stream and disconnect.
  Future<Result<void>> stopDataStream() async {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    await _controller?.close();
    _controller = null;
    _streaming = false;
    _connectedDeviceId = null;
    return const Success(null);
  }

  /// Returns the current simulated sampling rate.
  Future<Result<double>> getSamplingRate() async {
    if (!_streaming) {
      return const AppError(
        BluetoothFailure('Not connected to a sensor.'),
      );
    }
    return Success(_simulatedSamplingRate);
  }
}
