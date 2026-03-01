import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Large circular button used to trigger image capture.
///
/// Shows a [CircularProgressIndicator] when [isCapturing] is `true` and
/// disables taps until the capture completes.
class CaptureButton extends StatelessWidget {
  const CaptureButton({
    super.key,
    required this.onPressed,
    this.isCapturing = false,
  });

  /// Called when the user taps the button (ignored while [isCapturing]).
  final VoidCallback? onPressed;

  /// Whether a capture operation is currently in progress.
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Capture photo',
      child: GestureDetector(
        onTap: isCapturing ? null : onPressed,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCapturing ? Colors.grey.shade600 : AppTheme.primary,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: isCapturing
              ? const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : const Icon(
                  Icons.camera,
                  color: Colors.white,
                  size: 36,
                ),
        ),
      ),
    );
  }
}
