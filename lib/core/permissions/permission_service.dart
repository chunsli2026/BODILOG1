import 'package:permission_handler/permission_handler.dart';

import '../error/failures.dart';
import '../error/result.dart';

/// Centralised service for requesting and checking runtime permissions.
class PermissionService {
  const PermissionService();

  /// Requests camera permission.
  ///
  /// Returns [Success<bool>] with `true` when granted, or a
  /// [PermissionFailure] when denied.
  Future<Result<bool>> requestCameraPermission() async {
    return _requestPermission(Permission.camera, 'Camera');
  }

  /// Requests Bluetooth permissions (scan + connect on Android 12+).
  ///
  /// Returns [Success<bool>] with `true` when all permissions are granted.
  Future<Result<bool>> requestBluetoothPermissions() async {
    final results = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final allGranted = results.values.every(
      (status) => status == PermissionStatus.granted,
    );

    if (allGranted) {
      return const Success(true);
    }
    return const AppError(
      PermissionFailure('Bluetooth permissions were denied.'),
    );
  }

  /// Requests location permission required for BLE device scanning.
  ///
  /// Returns [Success<bool>] with `true` when granted.
  Future<Result<bool>> requestLocationPermission() async {
    return _requestPermission(Permission.locationWhenInUse, 'Location');
  }

  /// Checks whether camera permission is currently granted.
  Future<bool> isCameraPermissionGranted() async {
    return Permission.camera.isGranted;
  }

  /// Checks whether Bluetooth scan permission is currently granted.
  Future<bool> isBluetoothPermissionGranted() async {
    return Permission.bluetoothScan.isGranted;
  }

  /// Checks whether location permission is currently granted.
  Future<bool> isLocationPermissionGranted() async {
    return Permission.locationWhenInUse.isGranted;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Result<bool>> _requestPermission(
    Permission permission,
    String name,
  ) async {
    final status = await permission.request();
    if (status == PermissionStatus.granted) {
      return const Success(true);
    }
    return AppError(PermissionFailure('$name permission was denied.'));
  }
}
