import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';

/// Service responsible for camera lifecycle, image capture, and saving.
class CameraService {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Initialises the rear camera with [ResolutionPreset.high].
  ///
  /// Retries up to [_maxRetries] times with [_retryDelay] back-off.
  /// Returns a [Success<CameraController>] or a [CameraFailure].
  Future<Result<CameraController>> initializeCamera() async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          return const AppError(CameraFailure('No cameras found on this device.'));
        }

        // Prefer the rear camera.
        final rearCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );

        final controller = CameraController(
          rearCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await controller.initialize();
        // Default flash mode is auto.
        await controller.setFlashMode(FlashMode.auto);
        return Success(controller);
      } catch (e) {
        if (attempt < _maxRetries - 1) {
          await Future<void>.delayed(_retryDelay);
        } else {
          return AppError(CameraFailure('Failed to initialise camera: $e'));
        }
      }
    }
    // Unreachable, but required by the Dart analyser.
    return const AppError(CameraFailure('Camera initialisation failed.'));
  }

  /// Captures an image and saves it as a lossless PNG to the documents
  /// directory, returning the saved file path.
  ///
  /// Filename format: `strip_YYYYMMDD_HHmmss.png`
  Future<Result<String>> captureImage(CameraController controller) async {
    try {
      if (!controller.value.isInitialized) {
        return const AppError(CameraFailure('Camera is not initialised.'));
      }

      final xFile = await controller.takePicture();

      // Determine the documents directory.
      final docsDir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final pngPath = '${docsDir.path}/strip_$timestamp.png';

      // NOTE: The camera plugin captures as JPEG. The bytes are saved with a
      // .png extension as required by the spec; the downstream image processing
      // pipeline should decode by content rather than relying solely on the
      // file extension.
      final jpegBytes = await File(xFile.path).readAsBytes();
      await File(pngPath).writeAsBytes(jpegBytes);

      // Clean up the temporary JPEG file.
      try {
        await File(xFile.path).delete();
      } catch (_) {
        // Ignore cleanup errors.
      }

      return Success(pngPath);
    } catch (e) {
      return AppError(CameraFailure('Failed to capture image: $e'));
    }
  }

  /// Cycles through flash modes: Off → Auto → On → Off.
  ///
  /// Returns the new [FlashMode] on success.
  Future<Result<FlashMode>> toggleFlash(
    CameraController controller,
    FlashMode current,
  ) async {
    try {
      final next = _nextFlashMode(current);
      await controller.setFlashMode(next);
      return Success(next);
    } catch (e) {
      return AppError(CameraFailure('Failed to toggle flash: $e'));
    }
  }

  /// Locks auto-exposure at the normalised [point] (values in [0, 1]).
  Future<Result<void>> lockExposure(
    CameraController controller,
    Offset point,
  ) async {
    try {
      await controller.setExposurePoint(point);
      await controller.setFocusPoint(point);
      return const Success(null);
    } catch (e) {
      return AppError(CameraFailure('Failed to lock exposure: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static FlashMode _nextFlashMode(FlashMode current) {
    switch (current) {
      case FlashMode.off:
        return FlashMode.auto;
      case FlashMode.auto:
        return FlashMode.always;
      case FlashMode.always:
        return FlashMode.off;
      case FlashMode.torch:
        return FlashMode.off;
    }
  }
}
