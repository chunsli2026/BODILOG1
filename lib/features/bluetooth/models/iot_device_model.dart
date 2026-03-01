import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../shared/models/health_reading.dart';
import '../../../core/constants/app_constants.dart';
import 'ble_connection_state.dart';

/// Represents a BLE health-monitoring device discovered or paired by the app.
class IoTDevice {
  /// Creates an [IoTDevice].
  const IoTDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.serviceUuid,
    this.rssi,
    this.connectionState = BleConnectionState.disconnected,
    this.lastConnected,
    this.lastReading,
    this.isPaired = false,
  });

  /// BLE device ID / MAC address.
  final String id;

  /// Device display name.
  final String name;

  /// Device category.
  final DeviceType type;

  /// Primary BLE service UUID.
  final String serviceUuid;

  /// Signal strength (dBm) captured during a scan, or `null` when not scanning.
  final int? rssi;

  /// Current BLE connection state for this device.
  final BleConnectionState connectionState;

  /// Timestamp of the last successful connection.
  final DateTime? lastConnected;

  /// Timestamp of the most recent data reading.
  final DateTime? lastReading;

  /// Whether this device is saved as a paired device.
  final bool isPaired;

  // ---------------------------------------------------------------------------
  // Derived properties
  // ---------------------------------------------------------------------------

  /// Returns the Material icon that best represents [type].
  IconData get icon {
    switch (type) {
      case DeviceType.smartScale:
        return Icons.monitor_weight;
      case DeviceType.bloodPressureMonitor:
        return Icons.favorite;
      case DeviceType.thermometer:
        return Icons.thermostat;
      case DeviceType.pulseOximeter:
        return Icons.air;
      case DeviceType.wearableSensor:
        return Icons.watch;
    }
  }

  /// Returns a human-readable label for [type].
  String get typeDisplayName {
    switch (type) {
      case DeviceType.smartScale:
        return 'Smart Scale';
      case DeviceType.bloodPressureMonitor:
        return 'Blood Pressure Monitor';
      case DeviceType.thermometer:
        return 'Thermometer';
      case DeviceType.pulseOximeter:
        return 'Pulse Oximeter';
      case DeviceType.wearableSensor:
        return 'Wearable Sensor';
    }
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Converts this device to a [Map] suitable for insertion into SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'service_uuid': serviceUuid,
      'last_connected': lastConnected?.toIso8601String(),
      'last_reading': lastReading?.toIso8601String(),
    };
  }

  /// Creates an [IoTDevice] from a SQLite row [map].
  factory IoTDevice.fromMap(Map<String, dynamic> map) {
    return IoTDevice(
      id: map['id'] as String,
      name: map['name'] as String,
      type: DeviceType.values.byName(map['type'] as String),
      serviceUuid: map['service_uuid'] as String,
      lastConnected: map['last_connected'] != null
          ? DateTime.parse(map['last_connected'] as String)
          : null,
      lastReading: map['last_reading'] != null
          ? DateTime.parse(map['last_reading'] as String)
          : null,
      isPaired: true,
    );
  }

  /// Creates an [IoTDevice] from a BLE [ScanResult].
  ///
  /// The [DeviceType] and [serviceUuid] are inferred from the advertised
  /// service UUIDs. If no known UUID is found the device defaults to
  /// [DeviceType.wearableSensor].
  factory IoTDevice.fromScanResult(ScanResult result) {
    final advertisedUuids = result.advertisementData.serviceUuids
        .map((g) => g.toString().toLowerCase())
        .toList();

    DeviceType type;
    String serviceUuid;

    if (advertisedUuids.contains(AppConstants.bleServiceBodyComposition)) {
      type = DeviceType.smartScale;
      serviceUuid = AppConstants.bleServiceBodyComposition;
    } else if (advertisedUuids.contains(AppConstants.bleServiceBloodPressure)) {
      type = DeviceType.bloodPressureMonitor;
      serviceUuid = AppConstants.bleServiceBloodPressure;
    } else if (advertisedUuids.contains(AppConstants.bleServiceThermometer)) {
      type = DeviceType.thermometer;
      serviceUuid = AppConstants.bleServiceThermometer;
    } else if (advertisedUuids.contains(AppConstants.bleServicePulseOximeter)) {
      type = DeviceType.pulseOximeter;
      serviceUuid = AppConstants.bleServicePulseOximeter;
    } else {
      type = DeviceType.wearableSensor;
      serviceUuid = AppConstants.bleServiceWearableSensor;
    }

    final deviceName = result.advertisementData.localName.isNotEmpty
        ? result.advertisementData.localName
        : result.device.platformName.isNotEmpty
            ? result.device.platformName
            : 'Unknown Device';

    return IoTDevice(
      id: result.device.remoteId.str,
      name: deviceName,
      type: type,
      serviceUuid: serviceUuid,
      rssi: result.rssi,
      connectionState: BleConnectionState.discovered,
    );
  }

  /// Creates a copy with the given fields replaced.
  IoTDevice copyWith({
    String? id,
    String? name,
    DeviceType? type,
    String? serviceUuid,
    int? rssi,
    BleConnectionState? connectionState,
    DateTime? lastConnected,
    DateTime? lastReading,
    bool? isPaired,
  }) {
    return IoTDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      rssi: rssi ?? this.rssi,
      connectionState: connectionState ?? this.connectionState,
      lastConnected: lastConnected ?? this.lastConnected,
      lastReading: lastReading ?? this.lastReading,
      isPaired: isPaired ?? this.isPaired,
    );
  }

  @override
  String toString() =>
      'IoTDevice(id: $id, name: $name, type: $type, state: $connectionState)';
}
