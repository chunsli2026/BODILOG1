import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../services/camera_service.dart';

// ---------------------------------------------------------------------------
// CameraService provider
// ---------------------------------------------------------------------------

/// Provides a singleton [CameraService] instance.
final cameraServiceProvider = Provider<CameraService>((_) => CameraService());

// ---------------------------------------------------------------------------
// CameraState
// ---------------------------------------------------------------------------

/// Represents the state of the camera feature.
class CameraState {
  const CameraState({
    this.controller,
    this.isInitialising = false,
    this.isCapturing = false,
    this.flashMode = FlashMode.auto,
    this.failure,
    this.capturedImagePath,
  });

  final CameraController? controller;
  final bool isInitialising;
  final bool isCapturing;
  final FlashMode flashMode;
  final Failure? failure;
  final String? capturedImagePath;

  bool get isReady =>
      controller != null && (controller!.value.isInitialized) && !isInitialising;

  CameraState copyWith({
    CameraController? controller,
    bool? isInitialising,
    bool? isCapturing,
    FlashMode? flashMode,
    Failure? failure,
    String? capturedImagePath,
    bool clearFailure = false,
    bool clearCaptured = false,
  }) {
    return CameraState(
      controller: controller ?? this.controller,
      isInitialising: isInitialising ?? this.isInitialising,
      isCapturing: isCapturing ?? this.isCapturing,
      flashMode: flashMode ?? this.flashMode,
      failure: clearFailure ? null : (failure ?? this.failure),
      capturedImagePath: clearCaptured
          ? null
          : (capturedImagePath ?? this.capturedImagePath),
    );
  }
}

// ---------------------------------------------------------------------------
// CameraNotifier
// ---------------------------------------------------------------------------

/// Manages [CameraState] and delegates to [CameraService].
class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier(this._service) : super(const CameraState());

  final CameraService _service;

  /// Initialises the camera, updating state accordingly.
  Future<void> initializeCamera() async {
    state = state.copyWith(isInitialising: true, clearFailure: true);

    final result = await _service.initializeCamera();

    if (result is Success<CameraController>) {
      state = state.copyWith(
        controller: result.data,
        isInitialising: false,
        flashMode: FlashMode.auto,
      );
    } else if (result is AppError<CameraController>) {
      state = state.copyWith(
        isInitialising: false,
        failure: result.failure,
      );
    }
  }

  /// Captures an image and stores the path in [CameraState.capturedImagePath].
  Future<void> captureImage() async {
    final controller = state.controller;
    if (controller == null) return;

    state = state.copyWith(isCapturing: true, clearFailure: true);

    final result = await _service.captureImage(controller);

    if (result is Success<String>) {
      state = state.copyWith(
        isCapturing: false,
        capturedImagePath: result.data,
      );
    } else if (result is AppError<String>) {
      state = state.copyWith(
        isCapturing: false,
        failure: result.failure,
      );
    }
  }

  /// Toggles the flash mode and updates state.
  Future<void> toggleFlash() async {
    final controller = state.controller;
    if (controller == null) return;

    final result = await _service.toggleFlash(controller, state.flashMode);

    if (result is Success<FlashMode>) {
      state = state.copyWith(flashMode: result.data);
    } else if (result is AppError<FlashMode>) {
      state = state.copyWith(failure: result.failure);
    }
  }

  /// Locks auto-exposure at [point] (normalised [0, 1] coordinates).
  Future<void> lockExposure(double x, double y) async {
    final controller = state.controller;
    if (controller == null) return;

    final result = await _service.lockExposure(
      controller,
      Offset(x, y),
    );

    if (result is AppError<void>) {
      state = state.copyWith(failure: result.failure);
    }
  }

  /// Clears the captured image path so the camera screen is shown again.
  void clearCapturedImage() {
    state = state.copyWith(clearCaptured: true);
  }

  /// Disposes the [CameraController] and resets state.
  Future<void> dispose() async {
    await state.controller?.dispose();
    state = const CameraState();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Riverpod [StateNotifierProvider] exposing [CameraState].
final cameraProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  final service = ref.watch(cameraServiceProvider);
  return CameraNotifier(service);
});
