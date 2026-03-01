import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../services/camera_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides a singleton [CameraService] instance.
final cameraServiceProvider = Provider<CameraService>((ref) {
  return const CameraService();
});

// ---------------------------------------------------------------------------
// Simple state providers
// ---------------------------------------------------------------------------

/// Current flash mode.  Defaults to [FlashMode.auto].
final flashModeProvider = StateProvider<FlashMode>((ref) => FlashMode.auto);

/// File path of the most recently captured image, or `null` if none.
final capturedImagePathProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Camera controller notifier
// ---------------------------------------------------------------------------

/// Manages the lifecycle of a [CameraController] as an [AsyncNotifier].
///
/// Consumers watch [cameraControllerProvider] to react to loading / error /
/// data states and call [initializeCamera] / [disposeCamera] as needed.
class CameraControllerNotifier
    extends AsyncNotifier<CameraController?> {
  @override
  Future<CameraController?> build() async {
    // Dispose the controller when the notifier is disposed (e.g. on hot
    // restart or when the owning scope is removed).
    ref.onDispose(() {
      state.whenData((controller) {
        if (controller != null) {
          ref.read(cameraServiceProvider).dispose(controller);
        }
      });
    });
    return null;
  }

  /// Initialises the camera and updates [state] accordingly.
  Future<void> initializeCamera() async {
    state = const AsyncLoading();
    final result =
        await ref.read(cameraServiceProvider).initializeCamera();
    state = switch (result) {
      Success(data: final controller) => AsyncData(controller),
      AppError(failure: final failure) =>
        AsyncError(failure, StackTrace.current),
    };
  }

  /// Disposes the active [CameraController] and resets [state] to `null`.
  Future<void> disposeCamera() async {
    final controller = state.valueOrNull;
    if (controller != null) {
      await ref.read(cameraServiceProvider).dispose(controller);
      state = const AsyncData(null);
    }
  }
}

/// Provides the [CameraControllerNotifier].
final cameraControllerProvider =
    AsyncNotifierProvider<CameraControllerNotifier, CameraController?>(
  CameraControllerNotifier.new,
);
