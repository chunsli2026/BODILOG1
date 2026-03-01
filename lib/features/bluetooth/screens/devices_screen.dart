import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../models/iot_device_model.dart';
import '../providers/bluetooth_providers.dart';
import '../widgets/device_list_tile.dart';
import '../widgets/scan_button.dart';

/// Main Devices screen with two tabs:
/// - **Paired Devices** — shows saved/paired BLE health devices.
/// - **Scan for New** — allows scanning for nearby BLE devices.
class DevicesScreen extends ConsumerStatefulWidget {
  /// Creates a [DevicesScreen].
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _scanSummary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Paired Devices'),
            Tab(text: 'Scan for New'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PairedDevicesTab(
            onDeviceTap: (device) {
              Navigator.pushNamed(
                context,
                AppRouter.deviceDetail,
                arguments: device,
              );
            },
          ),
          _ScanTab(
            scanSummary: _scanSummary,
            onScanComplete: (count) {
              setState(() {
                _scanSummary = count == 0
                    ? 'No devices found. Ensure your device is turned on and in pairing mode.'
                    : 'Scan Complete — $count device${count == 1 ? '' : 's'} found';
              });
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paired Devices tab
// ---------------------------------------------------------------------------

class _PairedDevicesTab extends ConsumerWidget {
  const _PairedDevicesTab({required this.onDeviceTap});

  final ValueChanged<IoTDevice> onDeviceTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairedAsync = ref.watch(pairedDevicesProvider);

    return pairedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (devices) {
        if (devices.isEmpty) {
          return _EmptyState(
            icon: Icons.bluetooth_disabled,
            message:
                'No paired devices. Scan for nearby devices to get started.',
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(pairedDevicesProvider.notifier).reconnectAll(),
          child: ListView.separated(
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final device = devices[index];
              return DeviceListTile(
                device: device,
                onTap: () => onDeviceTap(device),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Scan for New tab
// ---------------------------------------------------------------------------

class _ScanTab extends ConsumerWidget {
  const _ScanTab({
    required this.onScanComplete,
    this.scanSummary,
  });

  final ValueChanged<int> onScanComplete;
  final String? scanSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scannedDevices = ref.watch(scannedDevicesProvider);
    final isScanning = ref.watch(isScanningProvider);

    return Column(
      children: [
        const SizedBox(height: 24),
        ScanButton(
          onScanComplete: () => onScanComplete(scannedDevices.length),
        ),
        const SizedBox(height: 16),
        if (scanSummary != null && !isScanning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              scanSummary!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scannedDevices.isEmpty
                        ? AppTheme.warning
                        : AppTheme.success,
                  ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: scannedDevices.isEmpty && !isScanning
              ? const SizedBox.shrink()
              : ListView.separated(
                  itemCount: scannedDevices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = scannedDevices[index];
                    return DeviceListTile(
                      device: device,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (device.rssi != null)
                            RssiIndicator(rssi: device.rssi!),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _pairDevice(ref, device),
                            child: const Text('Pair'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pairDevice(WidgetRef ref, IoTDevice device) async {
    await ref.read(pairedDevicesProvider.notifier).pair(device);
  }
}

// ---------------------------------------------------------------------------
// Empty state helper
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
