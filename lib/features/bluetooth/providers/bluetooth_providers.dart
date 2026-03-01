import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../shared/database/database_helper.dart';
import '../../../shared/models/health_reading.dart';
import '../models/ble_connection_state.dart';
import '../models/iot_device_model.dart';
import '../services/bluetooth_service.dart';

// ---------------------------------------------------------------------------
// Core providers
// ---------------------------------------------------------------------------

/// Provides the singleton [BluetoothService] instance.
final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  ref.onDispose(service.dispose);
  return service;
});

/// Whether Bluetooth is currently available and enabled on the device.
final bluetoothAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(bluetoothServiceProvider);
  final result = await service.isBluetoothAvailable();
  return result is Success<bool> ? (result as Success<bool>).data : false;
});

// ---------------------------------------------------------------------------
// Scanning state
// ---------------------------------------------------------------------------

/// Whether a BLE scan is currently in progress.
final isScanningProvider = StateProvider<bool>((ref) => false);

/// [StateNotifier] managing the list of devices discovered during a scan.
class ScannedDevicesNotifier extends StateNotifier<List<IoTDevice>> {
  /// Creates a [ScannedDevicesNotifier].
  ScannedDevicesNotifier(this._service) : super([]);

  final BluetoothService _service;

  /// Starts a scan and populates the state with discovered devices.
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    state = [];
    final result = await _service.scanForDevices(timeout: timeout);
    if (result is Success<List<IoTDevice>>) {
      state = (result as Success<List<IoTDevice>>).data;
    }
  }

  /// Stops any ongoing scan.
  Future<void> stopScan() async {
    await _service.stopScan();
  }
}

/// Provider for the list of devices discovered during a BLE scan.
final scannedDevicesProvider =
    StateNotifierProvider<ScannedDevicesNotifier, List<IoTDevice>>((ref) {
  return ScannedDevicesNotifier(ref.read(bluetoothServiceProvider));
});

// ---------------------------------------------------------------------------
// Paired devices state
// ---------------------------------------------------------------------------

/// [StateNotifier] managing the persisted list of paired devices.
class PairedDevicesNotifier
    extends StateNotifier<AsyncValue<List<IoTDevice>>> {
  /// Creates a [PairedDevicesNotifier] and immediately loads paired devices.
  PairedDevicesNotifier(this._service) : super(const AsyncValue.loading()) {
    load();
  }

  final BluetoothService _service;

  /// Loads paired devices from storage and updates [state].
  ///
  /// Overridable to allow test subclasses to skip the database call.
  Future<void> load() async {
    state = const AsyncValue.loading();
    final result = await _service.getPairedDevices();
    if (result is Success<List<IoTDevice>>) {
      state = AsyncValue.data((result as Success<List<IoTDevice>>).data);
    } else if (result is AppError<List<IoTDevice>>) {
      state = AsyncValue.error(
        (result as AppError<List<IoTDevice>>).failure,
        StackTrace.current,
      );
    }
  }

  /// Reloads the paired device list from storage.
  Future<void> refresh() => load();

  /// Pairs [device] and refreshes the list.
  Future<void> pair(IoTDevice device) async {
    await _service.pairDevice(device);
    await load();
  }

  /// Unpairs [device] and refreshes the list.
  Future<void> unpair(IoTDevice device) async {
    await _service.unpairDevice(device);
    await load();
  }

  /// Attempts to reconnect all paired devices and refreshes the list.
  Future<void> reconnectAll() async {
    await _service.reconnectPairedDevices();
    await load();
  }
}

/// Provider for the persisted list of paired devices.
final pairedDevicesProvider =
    StateNotifierProvider<PairedDevicesNotifier, AsyncValue<List<IoTDevice>>>(
  (ref) => PairedDevicesNotifier(ref.read(bluetoothServiceProvider)),
);

// ---------------------------------------------------------------------------
// Per-device connection state
// ---------------------------------------------------------------------------

/// Tracks the [BleConnectionState] for a specific device (keyed by device ID).
final deviceConnectionStateProvider =
    StateProvider.family<BleConnectionState, String>(
  (ref, deviceId) => BleConnectionState.disconnected,
);

// ---------------------------------------------------------------------------
// Health readings per device
// ---------------------------------------------------------------------------

/// Loads the list of [HealthReading]s for [deviceId] from SQLite.
final deviceReadingsProvider =
    FutureProvider.family<List<HealthReading>, String>((ref, deviceId) async {
  return DatabaseHelper.instance.getReadingsByDeviceId(deviceId);
});
