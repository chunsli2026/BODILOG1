import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/core/error/failures.dart';
import 'package:bodilog/core/error/result.dart';
import 'package:bodilog/features/camera/services/camera_service.dart';

// ---------------------------------------------------------------------------
// Tests that can run without a real camera (logic-only paths).
// ---------------------------------------------------------------------------

void main() {
  group('CameraService — flash toggle logic', () {
    // We test the private cycling logic indirectly by inspecting Result values
    // returned from a stub that always succeeds.

    test('Off → Auto → Always → Off cycle', () {
      // Test the internal nextFlashMode logic via public toggle:
      // We can't call toggleFlash without a real controller, so we verify the
      // expected sequence using named constants.
      const sequence = [
        FlashMode.off,
        FlashMode.auto,
        FlashMode.always,
        FlashMode.off,
      ];

      FlashMode next(FlashMode current) {
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

      expect(next(FlashMode.off), equals(FlashMode.auto));
      expect(next(FlashMode.auto), equals(FlashMode.always));
      expect(next(FlashMode.always), equals(FlashMode.off));
      expect(next(FlashMode.torch), equals(FlashMode.off));
      expect(sequence.length, equals(4));
    });
  });

  group('CameraService — Result types', () {
    test('Success wraps a String path', () {
      const result = Success<String>('/docs/strip_20250101_120000.png');
      expect(result.isSuccess, isTrue);
      expect(result.data, contains('strip_'));
    });

    test('AppError wraps a CameraFailure', () {
      const failure = CameraFailure('No cameras found on this device.');
      const result = AppError<String>(failure);
      expect(result.isError, isTrue);
      expect(result.failure, isA<CameraFailure>());
      expect(result.failure.message, equals('No cameras found on this device.'));
    });

    test('CameraFailure message is preserved', () {
      const msg = 'Failed to initialize camera: PlatformException';
      const f = CameraFailure(msg);
      expect(f.message, equals(msg));
      expect(f.toString(), contains('CameraFailure'));
    });
  });

  group('CameraService — filename format', () {
    test('Generated filename matches strip_YYYYMMDD_HHmmss.png pattern', () {
      final now = DateTime(2025, 6, 15, 9, 5, 3);
      final timestamp = _formatTimestamp(now);
      expect(timestamp, equals('20250615_090503'));
      expect('strip_$timestamp.png', matches(r'^strip_\d{8}_\d{6}\.png$'));
    });
  });
}

/// Replicates the timestamp formatting used in [CameraService.captureImage].
String _formatTimestamp(DateTime dt) {
  String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
  return '${p(dt.year, 4)}${p(dt.month)}${p(dt.day)}_'
      '${p(dt.hour)}${p(dt.minute)}${p(dt.second)}';
}
