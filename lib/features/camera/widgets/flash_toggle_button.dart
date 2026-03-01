import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// A button that cycles through flash modes: Off → Auto → On.
class FlashToggleButton extends StatelessWidget {
  const FlashToggleButton({
    super.key,
    required this.flashMode,
    required this.onToggle,
  });

  /// The currently active flash mode.
  final FlashMode flashMode;

  /// Callback invoked when the user taps to cycle the flash mode.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      tooltip: _tooltip(flashMode),
      icon: Icon(
        _icon(flashMode),
        color: Colors.white,
        size: 28,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4),
        ],
      ),
    );
  }

  static IconData _icon(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
    }
  }

  static String _tooltip(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return 'Flash off';
      case FlashMode.auto:
        return 'Flash auto';
      case FlashMode.always:
        return 'Flash on';
      case FlashMode.torch:
        return 'Torch';
    }
  }
}
