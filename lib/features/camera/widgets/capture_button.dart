import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Large circular capture button displayed at the bottom of the camera screen.
class CaptureButton extends StatelessWidget {
  const CaptureButton({
    super.key,
    required this.onPressed,
    this.isCapturing = false,
  });

  /// Called when the user taps to capture a photo.
  final VoidCallback? onPressed;

  /// When `true`, a progress indicator is shown instead of the camera icon.
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primary,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isCapturing
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.camera_alt, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}
