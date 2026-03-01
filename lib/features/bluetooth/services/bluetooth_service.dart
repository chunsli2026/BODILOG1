import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../../shared/database/database_helper.dart';
import '../../../shared/models/health_reading.dart';
import '../models/ble_connection_state.dart';
import '../models/iot_device_model.dart';

/// Supported BLE service UUIDs used when filtering scan results.
const List<String> _kSupportedServiceUuids = [
  AppConstants.bleServiceBodyComposition,
  AppConstants.bleServiceBloodPressure,
  AppConstants.bleServiceThermometer,
  AppConstants.bleServicePulseOximeter,
  AppConstants.bleServiceWearableSensor,
];

/// Main BLE service that manages scanning, connection, and data reading for
/// BodiLog health-monitoring devices.
class BluetoothService {
  BluetoothService({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  // Keeps track of active device connections keyed by device ID.
  final Map<String, fbp.BluetoothDevice> _connectedDevices = {};

  // ---------------------------------------------------------------------------
  // Availability
  // ---------------------------------------------------------------------------

  /// Checks if Bluetooth is available and enabled on the device.
  Future<Result<bool>> isBluetoothAvailable() async {
    try {
      if (!await fbp.FlutterBluePlus.isSupported) {
        return const Success(false);
      }
      final adapterState = await fbp.FlutterBluePlus.adapterState.first;
      return Success(adapterState == fbp.BluetoothAdapterState.on);
    } catch (e) {
      return AppError(GeneralFailure('Failed to check Bluetooth state: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Starts scanning for BLE devices that advertise a supported service UUID.
  ///
  /// Scanning stops automatically after [timeout] (default: 10 seconds).
  /// Returns a list of discovered [IoTDevice]s.
  Future<Result<List<IoTDevice>>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final available = await isBluetoothAvailable();
      if (available is AppError<bool>) return AppError(available.failure);
      if (available is Success<bool> && !available.data) {
        return const AppError(BluetoothDisabledFailure());
      }

      final serviceGuids =
          _kSupportedServiceUuids.map(fbp.Guid.new).toList();

      final discovered = <String, IoTDevice>{};

      final sub = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final advertisedUuids = result.advertisementData.serviceUuids
              .map((g) => g.toString().toLowerCase())
              .toList();
          final isSupported = _kSupportedServiceUuids
              .any((uuid) => advertisedUuids.contains(uuid));
          if (isSupported) {
            final device = IoTDevice.fromScanResult(result);
            discovered[device.id] = device;
          }
        }
      });

      await fbp.FlutterBluePlus.startScan(
        withServices: serviceGuids,
        timeout: timeout,
      );

      await fbp.FlutterBluePlus.isScanning
          .where((scanning) => !scanning)
          .first
          .timeout(timeout + const Duration(seconds: 2));

      await sub.cancel();

      return Success(discovered.values.toList());
    } on TimeoutException {
      return const AppError(ConnectionTimeoutFailure());
    } catch (e) {
      return AppError(BluetoothFailure('Scan failed: $e'));
    }
  }

  /// Stops an ongoing BLE scan.
  Future<Result<void>> stopScan() async {
    try {
      await fbp.FlutterBluePlus.stopScan();
      return const Success(null);
    } catch (e) {
      return AppError(BluetoothFailure('Failed to stop scan: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Connection management
  // ---------------------------------------------------------------------------

  /// Connects to [device].
  ///
  /// Times out after [timeout] (default: 30 seconds). Returns the [IoTDevice]
  /// with its [connectionState] updated to [BleConnectionState.connected] on
  /// success.
  Future<Result<IoTDevice>> connectToDevice(
    IoTDevice device, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final bleDevice = fbp.BluetoothDevice.fromId(device.id);

      await bleDevice.connect(timeout: timeout);

      _connectedDevices[device.id] = bleDevice;

      final connected = device.copyWith(
        connectionState: BleConnectionState.connected,
        lastConnected: DateTime.now(),
      );
      return Success(connected);
    } on TimeoutException {
      return const AppError(ConnectionTimeoutFailure());
    } on fbp.FlutterBluePlusException catch (e) {
      return AppError(BluetoothFailure('Connection failed: $e'));
    } catch (e) {
      return AppError(BluetoothFailure('Connection failed: $e'));
    }
  }

  /// Disconnects from [device].
  Future<Result<void>> disconnectFromDevice(IoTDevice device) async {
    try {
      final bleDevice =
          _connectedDevices[device.id] ?? fbp.BluetoothDevice.fromId(device.id);
      await bleDevice.disconnect();
      _connectedDevices.remove(device.id);
      return const Success(null);
    } catch (e) {
      return AppError(BluetoothFailure('Disconnect failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Data reading
  // ---------------------------------------------------------------------------

  /// Reads data from a connected [device].
  ///
  /// Discovers services, reads the primary characteristic, and parses the
  /// raw bytes into a [HealthReading].
  Future<Result<HealthReading>> readDeviceData(IoTDevice device) async {
    try {
      final bleDevice = _connectedDevices[device.id];
      if (bleDevice == null) {
        return const AppError(
          BluetoothFailure('Device is not connected.'),
        );
      }

      final services = await bleDevice.discoverServices();
      final targetUuid = fbp.Guid(device.serviceUuid);

      fbp.BluetoothService? targetService;
      for (final s in services) {
        if (s.serviceUuid == targetUuid) {
          targetService = s;
          break;
        }
      }

      if (targetService == null) {
        return const AppError(DataTransferFailure());
      }

      // Read the first readable characteristic from the target service.
      fbp.BluetoothCharacteristic? characteristic;
      for (final c in targetService.characteristics) {
        if (c.properties.read || c.properties.notify) {
          characteristic = c;
          break;
        }
      }

      if (characteristic == null) {
        return const AppError(DataTransferFailure());
      }

      final rawData = await characteristic.read();
      final reading = _parseData(device, rawData);
      if (reading == null) {
        return const AppError(DataTransferFailure());
      }

      await _db.insertHealthReading(reading);
      return Success(reading);
    } catch (e) {
      return const AppError(DataTransferFailure());
    }
  }

  /// Subscribes to continuous notifications from [device].
  ///
  /// Useful for wearable sensors that stream accelerometer / gyroscope data.
  Stream<Result<HealthReading>> subscribeToDevice(IoTDevice device) async* {
    try {
      final bleDevice = _connectedDevices[device.id];
      if (bleDevice == null) {
        yield const AppError(BluetoothFailure('Device is not connected.'));
        return;
      }

      final services = await bleDevice.discoverServices();
      final targetUuid = fbp.Guid(device.serviceUuid);

      fbp.BluetoothService? targetService;
      for (final s in services) {
        if (s.serviceUuid == targetUuid) {
          targetService = s;
          break;
        }
      }

      if (targetService == null) {
        yield const AppError(DataTransferFailure());
        return;
      }

      fbp.BluetoothCharacteristic? characteristic;
      for (final c in targetService.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          characteristic = c;
          break;
        }
      }

      if (characteristic == null) {
        yield const AppError(DataTransferFailure());
        return;
      }

      await characteristic.setNotifyValue(true);

      await for (final rawData in characteristic.lastValueStream) {
        if (rawData.isEmpty) continue;
        final reading = _parseData(device, rawData);
        if (reading != null) {
          await _db.insertHealthReading(reading);
          yield Success(reading);
        }
      }
    } catch (e) {
      yield const AppError(DataTransferFailure());
    }
  }

  // ---------------------------------------------------------------------------
  // Paired device management
  // ---------------------------------------------------------------------------

  /// Returns all previously paired devices from local storage.
  Future<Result<List<IoTDevice>>> getPairedDevices() async {
    try {
      final rows = await _db.getPairedDevices();
      final devices = rows.map(IoTDevice.fromMap).toList();
      return Success(devices);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to load paired devices: $e'));
    }
  }

  /// Saves [device] as a paired device.
  Future<Result<void>> pairDevice(IoTDevice device) async {
    try {
      await _db.insertPairedDevice(device.copyWith(isPaired: true).toMap());
      return const Success(null);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to save paired device: $e'));
    }
  }

  /// Removes [device] from the paired device list.
  Future<Result<void>> unpairDevice(IoTDevice device) async {
    try {
      await _db.deletePairedDevice(device.id);
      return const Success(null);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to remove paired device: $e'));
    }
  }

  /// Attempts to reconnect to all previously paired devices.
  ///
  /// Returns a list of [IoTDevice]s with updated connection states.
  Future<Result<List<IoTDevice>>> reconnectPairedDevices() async {
    final pairedResult = await getPairedDevices();
    if (pairedResult is AppError<List<IoTDevice>>) {
      return pairedResult;
    }

    final paired = (pairedResult as Success<List<IoTDevice>>).data;
    final reconnected = <IoTDevice>[];

    for (final device in paired) {
      final result = await connectToDevice(device);
      if (result is Success<IoTDevice>) {
        reconnected.add(result.data);
        await _db.updatePairedDeviceTimestamp(device.id, DateTime.now());
      } else {
        reconnected.add(device);
      }
    }

    return Success(reconnected);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Disconnects all active connections and releases resources.
  Future<void> dispose() async {
    for (final device in _connectedDevices.values) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _connectedDevices.clear();
  }

  // ---------------------------------------------------------------------------
  // GATT data parsing
  // ---------------------------------------------------------------------------

  /// Parses [rawData] bytes from [device] into a [HealthReading].
  ///
  /// Returns `null` when the data cannot be parsed.
  HealthReading? _parseData(IoTDevice device, List<int> rawData) {
    try {
      switch (device.type) {
        case DeviceType.smartScale:
          return _parseBodyComposition(device, rawData);
        case DeviceType.bloodPressureMonitor:
          return _parseBloodPressure(device, rawData);
        case DeviceType.thermometer:
          return _parseThermometer(device, rawData);
        case DeviceType.pulseOximeter:
          return _parsePulseOximeter(device, rawData);
        case DeviceType.wearableSensor:
          return _parseWearableSensor(device, rawData);
      }
    } catch (_) {
      return null;
    }
  }

  /// Parses a Body Composition Measurement characteristic (0x181B).
  ///
  /// Byte layout (Bluetooth SIG specification):
  /// - Byte 0–1 : Flags (little-endian)
  ///   - Bit 0   : Measurement Units (0 = kg & m, 1 = lbs & inch)
  ///   - Bit 1   : Time Stamp present
  ///   - Bit 2   : User ID present
  ///   - Bit 3   : Basal Metabolism present
  ///   - Bit 4   : Muscle Percentage present
  ///   - Bit 5   : Muscle Mass present
  ///   - Bit 6   : Fat Free Mass present
  ///   - Bit 7   : Soft Lean Mass present
  ///   - Bit 8   : Body Water Mass present
  ///   - Bit 9   : Impedance present
  ///   - Bit 10  : Weight present
  ///   - Bit 11  : Height present
  ///   - Bit 12  : Multiple Packet Measurement
  /// - Byte 2–3 : Body Fat Percentage (uint16, resolution 0.1%)
  /// - Byte 4–5 : Weight (uint16, resolution 0.005 kg or 0.01 lbs)
  HealthReading _parseBodyComposition(IoTDevice device, List<int> rawData) {
    if (rawData.length < 4) {
      throw const FormatException('Body composition data too short');
    }

    final flags = rawData[0] | (rawData[1] << 8);
    final isImperial = (flags & 0x01) != 0;

    double? weightKg;
    double? bodyFatPercent;
    double? muscleMassKg;
    double? waterWeightKg;
    double? bmiValue;

    // Body Fat Percentage (bytes 2–3, resolution 0.1%)
    if (rawData.length >= 4) {
      final rawFat = rawData[2] | (rawData[3] << 8);
      bodyFatPercent = rawFat * 0.1;
    }

    // Weight (bytes 4–5)
    if ((flags & (1 << 10)) != 0 && rawData.length >= 6) {
      final rawWeight = rawData[4] | (rawData[5] << 8);
      if (isImperial) {
        // resolution 0.01 lbs → convert to kg
        weightKg = rawWeight * 0.01 * 0.453592;
      } else {
        // resolution 0.005 kg
        weightKg = rawWeight * 0.005;
      }
    }

    // Muscle Mass (bytes 6–7 if present)
    if ((flags & (1 << 5)) != 0 && rawData.length >= 8) {
      final rawMuscle = rawData[6] | (rawData[7] << 8);
      muscleMassKg = isImperial
          ? rawMuscle * 0.01 * 0.453592
          : rawMuscle * 0.005;
    }

    // Body Water Mass (bytes 8–9 if present)
    if ((flags & (1 << 8)) != 0 && rawData.length >= 10) {
      final rawWater = rawData[8] | (rawData[9] << 8);
      waterWeightKg = isImperial
          ? rawWater * 0.01 * 0.453592
          : rawWater * 0.005;
    }

    final values = <String, double>{};
    if (weightKg != null) values['weight'] = weightKg;
    if (bodyFatPercent != null) values['bodyFat'] = bodyFatPercent;
    if (muscleMassKg != null) values['muscleMass'] = muscleMassKg;
    if (waterWeightKg != null) values['waterWeight'] = waterWeightKg;
    if (bmiValue != null) values['bmi'] = bmiValue;

    return HealthReading(
      id: _generateId(),
      deviceType: DeviceType.smartScale,
      timestamp: DateTime.now(),
      values: values,
      unit: 'kg',
      deviceId: device.id,
      deviceName: device.name,
      rawData: rawData,
    );
  }

  /// Parses a Blood Pressure Measurement characteristic (0x1810).
  ///
  /// Byte layout (Bluetooth SIG specification):
  /// - Byte 0   : Flags
  ///   - Bit 0  : Blood Pressure Units (0 = mmHg, 1 = kPa)
  ///   - Bit 1  : Time Stamp present
  ///   - Bit 2  : Pulse Rate present
  ///   - Bit 3  : User ID present
  ///   - Bit 4  : Measurement Status present
  /// - Byte 1–2 : Systolic (SFLOAT, mmHg or kPa)
  /// - Byte 3–4 : Diastolic (SFLOAT)
  /// - Byte 5–6 : MAP (SFLOAT)
  /// - Byte 7–8 : Pulse Rate (SFLOAT) — if Bit 2 of flags set
  HealthReading _parseBloodPressure(IoTDevice device, List<int> rawData) {
    if (rawData.length < 7) {
      throw const FormatException('Blood pressure data too short');
    }

    final flags = rawData[0];
    // final isKpa = (flags & 0x01) != 0; // stored as mmHg after conversion

    double systolic = _sfloatToDouble(rawData[1], rawData[2]);
    double diastolic = _sfloatToDouble(rawData[3], rawData[4]);
    // MAP at bytes 5–6 is not stored

    double? pulseRate;
    if ((flags & 0x04) != 0 && rawData.length >= 9) {
      pulseRate = _sfloatToDouble(rawData[7], rawData[8]);
    }

    final values = <String, double>{
      'systolic': systolic,
      'diastolic': diastolic,
    };
    if (pulseRate != null) values['pulseRate'] = pulseRate;

    return HealthReading(
      id: _generateId(),
      deviceType: DeviceType.bloodPressureMonitor,
      timestamp: DateTime.now(),
      values: values,
      unit: 'mmHg',
      deviceId: device.id,
      deviceName: device.name,
      rawData: rawData,
    );
  }

  /// Parses a Health Thermometer Measurement characteristic (0x1809).
  ///
  /// Byte layout (Bluetooth SIG specification):
  /// - Byte 0   : Flags
  ///   - Bit 0  : Temperature Units (0 = Celsius, 1 = Fahrenheit)
  ///   - Bit 1  : Time Stamp present
  ///   - Bit 2  : Temperature Type present
  /// - Byte 1–4 : Temperature Measurement Value (IEEE-11073 FLOAT, 4 bytes)
  /// - Byte 5   : Temperature Type (if present) —
  ///              1=Armpit, 2=Body, 3=Ear, 4=Finger, 5=GI, 6=Mouth, 7=Rectum,
  ///              8=Toe, 9=Tympanum
  HealthReading _parseThermometer(IoTDevice device, List<int> rawData) {
    if (rawData.length < 5) {
      throw const FormatException('Thermometer data too short');
    }

    final flags = rawData[0];
    final isFahrenheit = (flags & 0x01) != 0;

    double tempRaw = _ieee11073FloatToDouble(
      rawData[1], rawData[2], rawData[3], rawData[4],
    );

    // Convert °F → °C for consistent storage.
    double tempCelsius = isFahrenheit ? (tempRaw - 32) * 5 / 9 : tempRaw;

    return HealthReading(
      id: _generateId(),
      deviceType: DeviceType.thermometer,
      timestamp: DateTime.now(),
      values: {'temperature': tempCelsius},
      unit: '°C',
      deviceId: device.id,
      deviceName: device.name,
      rawData: rawData,
    );
  }

  /// Parses a Pulse Oximeter Continuous Measurement characteristic (0x1822).
  ///
  /// Byte layout (Bluetooth SIG specification):
  /// - Byte 0   : Flags
  /// - Byte 1–2 : SpO2 percentage (SFLOAT)
  /// - Byte 3–4 : Pulse Rate (SFLOAT)
  HealthReading _parsePulseOximeter(IoTDevice device, List<int> rawData) {
    if (rawData.length < 5) {
      throw const FormatException('Pulse oximeter data too short');
    }

    final spo2 = _sfloatToDouble(rawData[1], rawData[2]);
    final pulseRate = _sfloatToDouble(rawData[3], rawData[4]);

    return HealthReading(
      id: _generateId(),
      deviceType: DeviceType.pulseOximeter,
      timestamp: DateTime.now(),
      values: {'spo2': spo2, 'pulseRate': pulseRate},
      unit: '%',
      deviceId: device.id,
      deviceName: device.name,
      rawData: rawData,
    );
  }

  /// Parses custom wearable sensor data (accelerometer + gyroscope).
  ///
  /// Expected byte layout (little-endian int16 values, each scaled by 100):
  /// - Byte 0–1  : Accel X
  /// - Byte 2–3  : Accel Y
  /// - Byte 4–5  : Accel Z
  /// - Byte 6–7  : Gyro X
  /// - Byte 8–9  : Gyro Y
  /// - Byte 10–11: Gyro Z
  HealthReading _parseWearableSensor(IoTDevice device, List<int> rawData) {
    if (rawData.length < 12) {
      throw const FormatException('Wearable sensor data too short');
    }

    double readInt16(int lo, int hi) {
      int raw = lo | (hi << 8);
      if (raw >= 0x8000) raw -= 0x10000; // sign-extend
      return raw / 100.0;
    }

    return HealthReading(
      id: _generateId(),
      deviceType: DeviceType.wearableSensor,
      timestamp: DateTime.now(),
      values: {
        'accelX': readInt16(rawData[0], rawData[1]),
        'accelY': readInt16(rawData[2], rawData[3]),
        'accelZ': readInt16(rawData[4], rawData[5]),
        'gyroX': readInt16(rawData[6], rawData[7]),
        'gyroY': readInt16(rawData[8], rawData[9]),
        'gyroZ': readInt16(rawData[10], rawData[11]),
      },
      unit: 'm/s²',
      deviceId: device.id,
      deviceName: device.name,
      rawData: rawData,
    );
  }

  // ---------------------------------------------------------------------------
  // Low-level helpers
  // ---------------------------------------------------------------------------

  /// Converts a 16-bit Bluetooth SFLOAT (bytes [lo], [hi]) to a [double].
  double _sfloatToDouble(int lo, int hi) {
    final raw = lo | (hi << 8);
    // SFLOAT: upper 4 bits = exponent (signed), lower 12 bits = mantissa (signed)
    int exponent = (raw >> 12) & 0x0F;
    if (exponent >= 8) exponent -= 16; // sign-extend 4-bit value
    int mantissa = raw & 0x0FFF;
    if (mantissa >= 0x0800) mantissa -= 0x1000; // sign-extend 12-bit value
    return mantissa * _pow10(exponent);
  }

  /// Converts a 32-bit IEEE 11073 FLOAT (bytes [b0]..[b3], little-endian)
  /// to a [double].
  double _ieee11073FloatToDouble(int b0, int b1, int b2, int b3) {
    // b3 = exponent (int8), b0–b2 = mantissa (int24, little-endian)
    int exponent = b3;
    if (exponent >= 0x80) exponent -= 0x100; // sign-extend
    int mantissa = b0 | (b1 << 8) | (b2 << 16);
    if (mantissa >= 0x800000) mantissa -= 0x1000000; // sign-extend
    return mantissa * _pow10(exponent);
  }

  double _pow10(int exp) {
    if (exp == 0) return 1.0;
    double result = 1.0;
    if (exp > 0) {
      for (int i = 0; i < exp; i++) result *= 10.0;
    } else {
      for (int i = 0; i < -exp; i++) result /= 10.0;
    }
    return result;
  }

  /// Generates a simple unique ID using the current timestamp.
  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}
