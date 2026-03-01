import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/bluetooth/models/iot_device_model.dart';
import 'package:bodilog/features/bluetooth/providers/bluetooth_providers.dart';
import 'package:bodilog/features/bluetooth/screens/devices_screen.dart';
import 'package:bodilog/features/bluetooth/services/bluetooth_service.dart';

void main() {
  /// Wraps [widget] in the minimum providers needed for [DevicesScreen].
  Widget buildTestApp({
    List<IoTDevice> pairedDevices = const [],
    List<IoTDevice> scannedDevices = const [],
  }) {
    return ProviderScope(
      overrides: [
        pairedDevicesProvider.overrideWith(
          (ref) => _FakePairedDevicesNotifier(pairedDevices),
        ),
        scannedDevicesProvider.overrideWith(
          (ref) => _FakeScannedDevicesNotifier(scannedDevices),
        ),
      ],
      child: const MaterialApp(home: DevicesScreen()),
    );
  }

  testWidgets('Both tabs are present', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    expect(find.text('Paired Devices'), findsOneWidget);
    expect(find.text('Scan for New'), findsOneWidget);
  });

  testWidgets('Empty state message shown when no paired devices', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    expect(find.textContaining('No paired devices'), findsOneWidget);
  });

  testWidgets('Scan tab contains Start Scan button', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    // Switch to the "Scan for New" tab.
    await tester.tap(find.text('Scan for New'));
    await tester.pump();

    expect(find.text('Start Scan'), findsOneWidget);
  });

  testWidgets('Paired tab shows device names when devices exist', (tester) async {
    final devices = [
      IoTDevice(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'My Scale',
        type: DeviceType.smartScale,
        serviceUuid: '0000181b-0000-1000-8000-00805f9b34fb',
        isPaired: true,
      ),
    ];

    await tester.pumpWidget(buildTestApp(pairedDevices: devices));
    await tester.pump();

    expect(find.text('My Scale'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// Fake notifiers for testing — bypass BluetoothService and database
// ---------------------------------------------------------------------------

/// A [PairedDevicesNotifier] subclass that uses fixed in-memory data.
class _FakePairedDevicesNotifier extends PairedDevicesNotifier {
  _FakePairedDevicesNotifier(this._fixedDevices)
      : super(_NoOpBluetoothService());

  final List<IoTDevice> _fixedDevices;

  @override
  Future<void> load() async {
    // Skip the real database call; set state directly.
    state = AsyncValue.data(_fixedDevices);
  }
}

/// A [ScannedDevicesNotifier] subclass that uses fixed in-memory data.
class _FakeScannedDevicesNotifier extends ScannedDevicesNotifier {
  _FakeScannedDevicesNotifier(List<IoTDevice> devices)
      : super(_NoOpBluetoothService()) {
    state = devices;
  }

  @override
  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 10)}) async {
    // No-op for tests.
  }

  @override
  Future<void> stopScan() async {
    // No-op for tests.
  }
}

/// A [BluetoothService] that performs no real BLE operations.
///
/// Used by test notifiers to satisfy the constructor requirement without
/// touching the database or hardware.
class _NoOpBluetoothService extends BluetoothService {
  _NoOpBluetoothService();
}
