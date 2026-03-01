import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';

/// Encapsulates all camera operations for the BodiLog image capture module.
///
/// All public methods return [Result] types rather than throwing exceptions.
class CameraService {
  const CameraService();

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialises the rear camera controller at [ResolutionPreset.high].
  ///
  /// Attempts up to [_maxRetries] times with a [_retryDelay] between each
  /// attempt.  Returns [Success<CameraController>] on success or an
  /// [AppError<CameraController>] wrapping a [CameraFailure] on failure.
  Future<Result<CameraController>> initializeCamera() async {
    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          return const AppError(
            CameraFailure('No cameras are available on this device.'),
          );
        }

        // Prefer the rear-facing camera; fall back to the first available.
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
        await controller.setFlashMode(FlashMode.auto);
        return Success(controller);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < _maxRetries) {
          await Future<void>.delayed(_retryDelay);
        }
      }
    }

    return AppError(
      CameraFailure(
        'Camera initialisation failed after $_maxRetries attempts: $lastError',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  /// Captures an image, converts it to lossless PNG, and writes it to the
  /// app documents directory.
  ///
  /// Returns [Success<String>] with the absolute file path on success, or an
  /// [AppError<String>] wrapping a [CameraFailure] on failure.
  ///
  /// The filename format is `strip_YYYYMMDD_HHmmss.png`.
  Future<Result<String>> captureImage(CameraController controller) async {
    if (!controller.value.isInitialized) {
      return const AppError(
        CameraFailure('Camera is not initialised — cannot capture.'),
      );
    }

    try {
      final xFile = await controller.takePicture();
      final jpegBytes = await xFile.readAsBytes();

      // Decode the JPEG and re-encode as lossless PNG.
      final decoded = img.decodeImage(jpegBytes);
      if (decoded == null) {
        return const AppError(
          CameraFailure('Failed to decode the captured JPEG image.'),
        );
      }
      final pngBytes = Uint8List.fromList(img.encodePng(decoded));

      // Build output path.
      final docDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory(
        '${docDir.path}/${AppConstants.imageDirectoryName}',
      );
      if (!imageDir.existsSync()) {
        await imageDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${imageDir.path}/strip_$timestamp.png';

      await File(filePath).writeAsBytes(pngBytes);
      return Success(filePath);
    } catch (e) {
      return AppError(CameraFailure('Image capture failed: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Flash
  // ---------------------------------------------------------------------------

  /// Cycles the flash mode: Off → Auto → On → Off.
  ///
  /// Returns [Success<FlashMode>] with the newly applied mode, or an
  /// [AppError<FlashMode>] on failure.
  Future<Result<FlashMode>> toggleFlash(
    CameraController controller,
    FlashMode currentMode,
  ) async {
    try {
      final nextMode = switch (currentMode) {
        FlashMode.off => FlashMode.auto,
        FlashMode.auto => FlashMode.always,
        _ => FlashMode.off,
      };
      await controller.setFlashMode(nextMode);
      return Success(nextMode);
    } catch (e) {
      return AppError(CameraFailure('Failed to toggle flash mode: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Focus / Exposure
  // ---------------------------------------------------------------------------

  /// Locks auto-exposure (and focus) at the normalised [point] (0.0–1.0 in
  /// each axis) after a tap-to-focus gesture.
  ///
  /// Returns [Success<void>] on success or [AppError<void>] on failure.
  Future<Result<void>> lockExposure(
    CameraController controller,
    Offset point,
  ) async {
    try {
      if (controller.value.isInitialized) {
        await controller.setExposurePoint(point);
        await controller.setExposureMode(ExposureMode.locked);
      }
      return const Success(null);
    } catch (e) {
      return AppError(CameraFailure('Failed to lock exposure: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Disposes [controller] if it is currently initialised.
  Future<void> dispose(CameraController controller) async {
    if (controller.value.isInitialized) {
      await controller.dispose();
    }
  }
}
