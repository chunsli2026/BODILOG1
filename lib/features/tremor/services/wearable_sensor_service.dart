import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../models/sensor_data.dart';

/// Custom BLE service UUID for wearable sensors.
const String kWearableServiceUuid =
    '0000180d-0000-1000-8000-00805f9b34fb';

/// Characteristic UUID for sensor data stream.
const String kSensorDataCharUuid =
    '00002a37-0000-1000-8000-00805f9b34fb';

/// Characteristic UUID for sampling-rate query.
const String kSamplingRateCharUuid =
    '00002a38-0000-1000-8000-00805f9b34fb';

/// Default sampling rate when the device does not advertise one.
const double kDefaultSamplingRateHz = 50.0;

/// Manages BLE connectivity with a wearable accelerometer/gyroscope sensor.
///
/// Acquire sensor data by calling [connectToSensor], then [startDataStream].
/// Always call [disconnect] when done.
class WearableSensorService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _dataCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamController<Result<SensorDataPoint>>? _dataController;

  bool _isConnected = false;
  bool _isStreaming = false;
  int _recordingStartMs = 0;

  /// Whether a sensor device is currently connected.
  bool get isConnected => _isConnected;

  /// Whether the data stream is currently active.
  bool get isStreaming => _isStreaming;

  /// Connects to the BLE sensor device identified by [deviceId].
  Future<Result<void>> connectToSensor(String deviceId) async {
    try {
      // Find the device from the list of known/paired devices.
      final devices = FlutterBluePlus.connectedDevices;
      BluetoothDevice? target;
      for (final d in devices) {
        if (d.remoteId.str == deviceId) {
          target = d;
          break;
        }
      }

      if (target == null) {
        // Create a device reference and connect.
        target = BluetoothDevice.fromId(deviceId);
      }

      await target.connect(timeout: const Duration(seconds: 30));
      _device = target;

      // Discover services.
      final services = await target.discoverServices();
      BluetoothCharacteristic? dataChar;
      for (final service in services) {
        if (service.uuid.str.toLowerCase() ==
            kWearableServiceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.uuid.str.toLowerCase() ==
                kSensorDataCharUuid.toLowerCase()) {
              dataChar = char;
            }
          }
        }
      }

      if (dataChar == null) {
        await target.disconnect();
        return const AppError(BluetoothFailure(
            'Wearable sensor service not found on device.'));
      }

      _dataCharacteristic = dataChar;
      _isConnected = true;
      return const Success(null);
    } catch (e) {
      return AppError(BluetoothFailure('Connection failed: $e'));
    }
  }

  /// Starts streaming sensor data from the connected device.
  ///
  /// Returns a stream of [Result<SensorDataPoint>] at the device's
  /// sampling rate (≥ 50 Hz). Emits an [AppError] on BLE errors.
  Stream<Result<SensorDataPoint>> startDataStream() {
    if (!_isConnected || _dataCharacteristic == null) {
      return Stream.value(
          const AppError(BluetoothFailure('No sensor connected.')));
    }

    _dataController?.close();
    _dataController =
        StreamController<Result<SensorDataPoint>>.broadcast();
    _recordingStartMs =
        DateTime.now().millisecondsSinceEpoch;
    _isStreaming = true;

    _dataCharacteristic!.setNotifyValue(true).then((_) {
      _notifySubscription = _dataCharacteristic!.onValueReceived.listen(
        (bytes) {
          try {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final tsMs = nowMs - _recordingStartMs;
            final point =
                SensorDataPoint.fromBleBytes(bytes, tsMs);
            _dataController?.add(Success(point));
          } catch (e) {
            _dataController?.add(
                AppError(BluetoothFailure('Parse error: $e')));
          }
        },
        onError: (Object e) {
          _dataController?.add(
              AppError(BluetoothFailure('BLE error: $e')));
        },
        onDone: () {
          _isStreaming = false;
          _dataController?.close();
        },
      );
    }).catchError((Object e) {
      _dataController?.add(
          AppError(BluetoothFailure('Notify failed: $e')));
    });

    return _dataController!.stream;
  }

  /// Stops the data stream.
  Future<Result<void>> stopDataStream() async {
    try {
      _isStreaming = false;
      await _notifySubscription?.cancel();
      _notifySubscription = null;
      if (_dataCharacteristic != null) {
        await _dataCharacteristic!.setNotifyValue(false);
      }
      await _dataController?.close();
      _dataController = null;
      return const Success(null);
    } catch (e) {
      return AppError(BluetoothFailure('Stop stream failed: $e'));
    }
  }

  /// Queries the sensor's current sampling rate in Hz.
  ///
  /// Falls back to [kDefaultSamplingRateHz] when the characteristic is
  /// unavailable or returns unexpected data.
  Future<Result<double>> getSamplingRate() async {
    if (!_isConnected || _device == null) {
      return const AppError(
          BluetoothFailure('No sensor connected.'));
    }
    try {
      final services = await _device!.discoverServices();
      for (final service in services) {
        if (service.uuid.str.toLowerCase() ==
            kWearableServiceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.uuid.str.toLowerCase() ==
                kSamplingRateCharUuid.toLowerCase()) {
              final bytes = await char.read();
              if (bytes.length >= 2) {
                // Two-byte little-endian unsigned integer (e.g. 50, 100).
                final rate = bytes[0] | (bytes[1] << 8);
                return Success(rate.toDouble());
              }
            }
          }
        }
      }
      return const Success(kDefaultSamplingRateHz);
    } catch (e) {
      return const Success(kDefaultSamplingRateHz);
    }
  }

  /// Disconnects from the connected sensor device.
  Future<Result<void>> disconnect() async {
    try {
      await stopDataStream();
      await _device?.disconnect();
      _device = null;
      _dataCharacteristic = null;
      _isConnected = false;
      return const Success(null);
    } catch (e) {
      return AppError(BluetoothFailure('Disconnect failed: $e'));
    }
  }
}
