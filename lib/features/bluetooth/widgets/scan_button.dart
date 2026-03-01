import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../providers/bluetooth_providers.dart';

/// A button / indicator widget that starts or stops a BLE device scan.
///
/// While scanning, it displays a progress indicator and a "Stop Scan" label.
/// When idle, it shows a prominent "Start Scan" button.
class ScanButton extends ConsumerWidget {
  /// Creates a [ScanButton].
  const ScanButton({super.key, this.onScanComplete});

  /// Called when a scan completes (after the scanning state returns to false).
  final VoidCallback? onScanComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isScanning = ref.watch(isScanningProvider);

    if (isScanning) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _stopScan(ref),
            child: const Text('Stop Scan'),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _startScan(ref),
      icon: const Icon(Icons.bluetooth_searching),
      label: const Text('Start Scan'),
    );
  }

  Future<void> _startScan(WidgetRef ref) async {
    ref.read(isScanningProvider.notifier).state = true;
    await ref.read(scannedDevicesProvider.notifier).startScan();
    ref.read(isScanningProvider.notifier).state = false;
    onScanComplete?.call();
  }

  Future<void> _stopScan(WidgetRef ref) async {
    await ref.read(scannedDevicesProvider.notifier).stopScan();
    ref.read(isScanningProvider.notifier).state = false;
  }
}
