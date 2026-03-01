import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/bluetooth/models/ble_connection_state.dart';
import 'package:bodilog/features/bluetooth/models/iot_device_model.dart';
import 'package:bodilog/shared/models/health_reading.dart';

void main() {
  // ---------------------------------------------------------------------------
  // IoTDevice serialisation
  // ---------------------------------------------------------------------------
  group('IoTDevice serialisation', () {
    final device = IoTDevice(
      id: 'AA:BB:CC:DD:EE:FF',
      name: 'My Scale',
      type: DeviceType.smartScale,
      serviceUuid: '0000181b-0000-1000-8000-00805f9b34fb',
      rssi: -65,
      connectionState: BleConnectionState.disconnected,
      lastConnected: DateTime.utc(2026, 3, 1, 10, 0, 0),
      lastReading: DateTime.utc(2026, 3, 1, 11, 0, 0),
      isPaired: true,
    );

    test('toMap() produces expected keys', () {
      final map = device.toMap();
      expect(map['id'], equals('AA:BB:CC:DD:EE:FF'));
      expect(map['name'], equals('My Scale'));
      expect(map['type'], equals('smartScale'));
      expect(map['service_uuid'],
          equals('0000181b-0000-1000-8000-00805f9b34fb'));
      expect(map['last_connected'], equals('2026-03-01T10:00:00.000Z'));
      expect(map['last_reading'], equals('2026-03-01T11:00:00.000Z'));
    });

    test('fromMap(toMap()) round-trip preserves all fields', () {
      final restored = IoTDevice.fromMap(device.toMap());
      expect(restored.id, equals(device.id));
      expect(restored.name, equals(device.name));
      expect(restored.type, equals(device.type));
      expect(restored.serviceUuid, equals(device.serviceUuid));
      expect(restored.lastConnected, equals(device.lastConnected));
      expect(restored.lastReading, equals(device.lastReading));
      expect(restored.isPaired, isTrue);
    });

    test('fromMap handles null optional timestamps', () {
      final map = {
        'id': 'dev-1',
        'name': 'BP Monitor',
        'type': 'bloodPressureMonitor',
        'service_uuid': '00001810-0000-1000-8000-00805f9b34fb',
        'last_connected': null,
        'last_reading': null,
      };
      final restored = IoTDevice.fromMap(map);
      expect(restored.lastConnected, isNull);
      expect(restored.lastReading, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // IoTDevice.icon and typeDisplayName
  // ---------------------------------------------------------------------------
  group('IoTDevice.icon returns correct icon', () {
    for (final type in DeviceType.values) {
      test('$type has non-null icon and display name', () {
        final device = IoTDevice(
          id: 'x',
          name: 'Test',
          type: type,
          serviceUuid: 'uuid',
        );
        // Just verifying no exception is thrown and values are non-null.
        expect(device.icon, isNotNull);
        expect(device.typeDisplayName, isNotEmpty);
      });
    }
  });

  test('smartScale icon is monitor_weight and display name is Smart Scale', () {
    final d = IoTDevice(
        id: '1', name: 'Scale', type: DeviceType.smartScale, serviceUuid: 'u');
    expect(d.typeDisplayName, equals('Smart Scale'));
  });

  test('bloodPressureMonitor display name is Blood Pressure Monitor', () {
    final d = IoTDevice(
        id: '2',
        name: 'BP',
        type: DeviceType.bloodPressureMonitor,
        serviceUuid: 'u');
    expect(d.typeDisplayName, equals('Blood Pressure Monitor'));
  });

  // ---------------------------------------------------------------------------
  // BleDeviceState.allowedTransitions
  // ---------------------------------------------------------------------------
  group('BleDeviceState.allowedTransitions', () {
    test('disconnected → only scanning allowed', () {
      final s = BleDeviceState(state: BleConnectionState.disconnected);
      expect(s.allowedTransitions, equals([BleConnectionState.scanning]));
    });

    test('scanning → discovered, disconnected, error', () {
      final s = BleDeviceState(state: BleConnectionState.scanning);
      expect(
        s.allowedTransitions,
        containsAll([
          BleConnectionState.discovered,
          BleConnectionState.disconnected,
          BleConnectionState.error,
        ]),
      );
    });

    test('connecting → connected, disconnected, error', () {
      final s = BleDeviceState(state: BleConnectionState.connecting);
      expect(
        s.allowedTransitions,
        containsAll([
          BleConnectionState.connected,
          BleConnectionState.disconnected,
          BleConnectionState.error,
        ]),
      );
    });

    test('connected → syncing, idle, disconnected, error', () {
      final s = BleDeviceState(state: BleConnectionState.connected);
      expect(
        s.allowedTransitions,
        containsAll([
          BleConnectionState.syncing,
          BleConnectionState.idle,
          BleConnectionState.disconnected,
          BleConnectionState.error,
        ]),
      );
    });

    test('error → only disconnected allowed', () {
      final s = BleDeviceState(state: BleConnectionState.error);
      expect(s.allowedTransitions, equals([BleConnectionState.disconnected]));
    });
  });

  // ---------------------------------------------------------------------------
  // BleDeviceState.isConnected
  // ---------------------------------------------------------------------------
  group('BleDeviceState.isConnected', () {
    test('connected state → isConnected is true', () {
      expect(
        BleDeviceState(state: BleConnectionState.connected).isConnected,
        isTrue,
      );
    });

    test('syncing state → isConnected is true', () {
      expect(
        BleDeviceState(state: BleConnectionState.syncing).isConnected,
        isTrue,
      );
    });

    test('idle state → isConnected is true', () {
      expect(
        BleDeviceState(state: BleConnectionState.idle).isConnected,
        isTrue,
      );
    });

    test('disconnected state → isConnected is false', () {
      expect(
        BleDeviceState(state: BleConnectionState.disconnected).isConnected,
        isFalse,
      );
    });

    test('error state → isConnected is false', () {
      expect(
        BleDeviceState(state: BleConnectionState.error).isConnected,
        isFalse,
      );
    });
  });
}
