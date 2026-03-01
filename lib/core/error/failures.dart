/// Abstract base class for all application failures.
abstract class Failure {
  const Failure(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Failure related to camera initialisation, capture, or save operations.
class CameraFailure extends Failure {
  const CameraFailure(super.message);
}

/// Failure related to BLE connection or data-transfer operations.
class BluetoothFailure extends Failure {
  const BluetoothFailure(super.message);
}

/// Failure related to SQLite read/write operations.
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

/// Failure related to image processing and colour analysis.
class AnalysisFailure extends Failure {
  const AnalysisFailure(super.message);
}

/// Failure raised when a required runtime permission is denied.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Catch-all failure for unexpected errors.
class GeneralFailure extends Failure {
  const GeneralFailure(super.message);
}
