/// Formal BLE connection state machine for a single device.
enum BleConnectionState {
  /// Not connected to any device.
  disconnected,

  /// Actively scanning for devices.
  scanning,

  /// Device found during scan.
  discovered,

  /// Connection in progress.
  connecting,

  /// Connected to device.
  connected,

  /// Reading / syncing data from device.
  syncing,

  /// Connected but not actively syncing.
  idle,

  /// Error state (see [BleDeviceState.errorMessage] for details).
  error,
}

/// Holds the current [BleConnectionState] for a BLE device along with
/// optional error information and a timestamp of the last transition.
class BleDeviceState {
  /// Creates a [BleDeviceState].
  const BleDeviceState({
    this.state = BleConnectionState.disconnected,
    this.errorMessage,
    this.lastStateChange,
  });

  /// The current connection state.
  final BleConnectionState state;

  /// Human-readable error message when [state] is [BleConnectionState.error].
  final String? errorMessage;

  /// When the state last changed.
  final DateTime? lastStateChange;

  // ---------------------------------------------------------------------------
  // State-machine helpers
  // ---------------------------------------------------------------------------

  /// Returns the set of states that are valid to transition to from [state].
  ///
  /// Valid transitions:
  /// ```
  /// disconnected → scanning
  /// scanning     → discovered, disconnected, error
  /// discovered   → connecting, disconnected
  /// connecting   → connected, disconnected, error
  /// connected    → syncing, idle, disconnected, error
  /// syncing      → idle, disconnected, error
  /// idle         → syncing, disconnected, error
  /// error        → disconnected
  /// ```
  List<BleConnectionState> get allowedTransitions {
    switch (state) {
      case BleConnectionState.disconnected:
        return [BleConnectionState.scanning];
      case BleConnectionState.scanning:
        return [
          BleConnectionState.discovered,
          BleConnectionState.disconnected,
          BleConnectionState.error,
        ];
      case BleConnectionState.discovered:
        return [
          BleConnectionState.connecting,
          BleConnectionState.disconnected,
        ];
      case BleConnectionState.connecting:
        return [
          BleConnectionState.connected,
          BleConnectionState.disconnected,
          BleConnectionState.error,
        ];
      case BleConnectionState.connected:
        return [
          BleConnectionState.syncing,
          BleConnectionState.idle,
          BleConnectionState.disconnected,
          BleConnectionState.error,
        ];
      case BleConnectionState.syncing:
        return [
          BleConnectionState.idle,
          BleConnectionState.disconnected,
          BleConnectionState.error,
        ];
      case BleConnectionState.idle:
        return [
          BleConnectionState.syncing,
          BleConnectionState.disconnected,
          BleConnectionState.error,
        ];
      case BleConnectionState.error:
        return [BleConnectionState.disconnected];
    }
  }

  /// Returns `true` when the device is considered connected
  /// (i.e. [state] is [BleConnectionState.connected], [syncing], or [idle]).
  bool get isConnected =>
      state == BleConnectionState.connected ||
      state == BleConnectionState.syncing ||
      state == BleConnectionState.idle;

  /// Creates a copy with the given fields replaced.
  BleDeviceState copyWith({
    BleConnectionState? state,
    String? errorMessage,
    DateTime? lastStateChange,
  }) {
    return BleDeviceState(
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      lastStateChange: lastStateChange ?? this.lastStateChange,
    );
  }

  @override
  String toString() =>
      'BleDeviceState(state: $state, errorMessage: $errorMessage)';
}
