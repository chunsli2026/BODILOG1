import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../shared/models/health_reading.dart';
import '../models/ble_connection_state.dart';
import '../models/iot_device_model.dart';
import '../providers/bluetooth_providers.dart';

/// Screen showing the detail for a single [IoTDevice], including its
/// connection status, a "Sync Now" action, and reading history.
class DeviceDetailScreen extends ConsumerWidget {
  /// Creates a [DeviceDetailScreen].
  const DeviceDetailScreen({super.key, required this.device});

  /// The device to show details for.
  final IoTDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(
      deviceConnectionStateProvider(device.id),
    );
    final readingsAsync = ref.watch(deviceReadingsProvider(device.id));
    final isConnected = BleDeviceState(state: connectionState).isConnected;

    return Scaffold(
      appBar: AppBar(title: Text(device.name)),
      body: Column(
        children: [
          // ── Device header ───────────────────────────────────────────────────
          _DeviceHeader(device: device, connectionState: connectionState),
          const Divider(height: 1),

          // ── Action buttons ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: isConnected
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: const Text('Disconnect'),
                          onPressed: () => _disconnect(context, ref),
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.bluetooth),
                          label: const Text('Connect'),
                          onPressed: () => _connect(context, ref),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                    onPressed: isConnected ? () => _sync(context, ref) : null,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Reading history ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Reading History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: readingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (readings) {
                if (readings.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No readings yet. Tap Sync Now to get your first reading.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: readings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _ReadingTile(reading: readings[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    ref.read(deviceConnectionStateProvider(device.id).notifier).state =
        BleConnectionState.connecting;
    final result =
        await ref.read(bluetoothServiceProvider).connectToDevice(device);
    if (result.isSuccess) {
      ref.read(deviceConnectionStateProvider(device.id).notifier).state =
          BleConnectionState.connected;
    } else {
      ref.read(deviceConnectionStateProvider(device.id).notifier).state =
          BleConnectionState.error;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to device.')),
        );
      }
    }
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    await ref.read(bluetoothServiceProvider).disconnectFromDevice(device);
    ref.read(deviceConnectionStateProvider(device.id).notifier).state =
        BleConnectionState.disconnected;
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    ref.read(deviceConnectionStateProvider(device.id).notifier).state =
        BleConnectionState.syncing;
    final result =
        await ref.read(bluetoothServiceProvider).readDeviceData(device);
    ref.read(deviceConnectionStateProvider(device.id).notifier).state =
        BleConnectionState.idle;
    // Refresh reading list.
    ref.invalidate(deviceReadingsProvider(device.id));

    if (!result.isSuccess && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error reading data from device.')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Device header
// ---------------------------------------------------------------------------

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({
    required this.device,
    required this.connectionState,
  });

  final IoTDevice device;
  final BleConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    final deviceState = BleDeviceState(state: connectionState);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withAlpha(26),
            child: Icon(device.icon, size: 32, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.typeDisplayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                if (device.lastConnected != null)
                  Text(
                    'Last connected: ${DateFormat('MMM d, HH:mm').format(device.lastConnected!.toLocal())}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
              ],
            ),
          ),
          _StatusChip(isConnected: deviceState.isConnected),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        isConnected ? 'Connected' : 'Disconnected',
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: isConnected ? AppTheme.success : Colors.grey,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ---------------------------------------------------------------------------
// Reading tile
// ---------------------------------------------------------------------------

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.reading});

  final HealthReading reading;

  @override
  Widget build(BuildContext context) {
    final formatted = reading.values.entries
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} ${reading.unit}')
        .join('  ·  ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.secondary.withAlpha(26),
        child: Icon(
          _iconForType(reading.deviceType),
          color: AppTheme.secondary,
          size: 20,
        ),
      ),
      title: Text(
        formatted,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        DateFormat('MMM d, yyyy  HH:mm').format(reading.timestamp.toLocal()),
        style:
            Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
      ),
    );
  }

  IconData _iconForType(DeviceType type) {
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
}
