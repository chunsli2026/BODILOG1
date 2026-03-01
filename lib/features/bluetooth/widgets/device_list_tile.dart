import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../models/ble_connection_state.dart';
import '../models/iot_device_model.dart';

/// A list tile representing a single [IoTDevice].
///
/// Shows the device icon, name, type, connection status indicator, and the
/// time of the last reading (if available).
class DeviceListTile extends StatelessWidget {
  /// Creates a [DeviceListTile].
  const DeviceListTile({
    super.key,
    required this.device,
    this.onTap,
    this.trailing,
  });

  /// The device to display.
  final IoTDevice device;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Optional widget to display at the end of the tile (e.g. a "Pair" button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _DeviceIcon(device: device),
      title: Text(
        device.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        device.typeDisplayName,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: trailing ?? _ConnectionIndicator(state: device.connectionState),
      onTap: onTap,
    );
  }
}

/// Circular icon showing the device type.
class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.device});

  final IoTDevice device;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: AppTheme.primary.withAlpha(26),
      child: Icon(device.icon, color: AppTheme.primary),
    );
  }
}

/// A small coloured dot indicating BLE connection status:
/// - green  = connected / syncing / idle
/// - orange = connecting / scanning
/// - grey   = disconnected / discovered
/// - red    = error
class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({required this.state});

  final BleConnectionState state;

  Color get _color {
    switch (state) {
      case BleConnectionState.connected:
      case BleConnectionState.syncing:
      case BleConnectionState.idle:
        return AppTheme.success;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        return AppTheme.warning;
      case BleConnectionState.error:
        return AppTheme.error;
      case BleConnectionState.disconnected:
      case BleConnectionState.discovered:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A compact card showing a signal-strength bar and RSSI value.
class RssiIndicator extends StatelessWidget {
  /// Creates an [RssiIndicator].
  const RssiIndicator({super.key, required this.rssi});

  /// RSSI in dBm (typically −100 to 0).
  final int rssi;

  int get _bars {
    if (rssi >= -60) return 4;
    if (rssi >= -75) return 3;
    if (rssi >= -85) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _bars >= 4
              ? Icons.signal_wifi_4_bar
              : _bars == 3
                  ? Icons.network_wifi_3_bar
                  : _bars == 2
                      ? Icons.network_wifi_2_bar
                      : Icons.network_wifi_1_bar,
          size: 18,
          color: AppTheme.secondary,
        ),
        const SizedBox(width: 2),
        Text(
          '${rssi} dBm',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

/// Formats a nullable [DateTime] as a human-readable "last seen" string.
String formatLastSeen(DateTime? dt) {
  if (dt == null) return 'Never';
  return DateFormat('MMM d, HH:mm').format(dt.toLocal());
}
