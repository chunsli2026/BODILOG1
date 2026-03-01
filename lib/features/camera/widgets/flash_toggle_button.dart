import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Icon button that cycles through flash modes: Off → Auto → On → Off.
///
/// Displays an icon appropriate for [flashMode] and calls [onToggle] when
/// tapped.
class FlashToggleButton extends StatelessWidget {
  const FlashToggleButton({
    super.key,
    required this.flashMode,
    required this.onToggle,
  });

  /// The current flash mode to display.
  final FlashMode flashMode;

  /// Called when the user taps the button.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(flashMode);
    return IconButton(
      onPressed: onToggle,
      icon: Icon(
        _iconFor(flashMode),
        color: Colors.white,
        semanticLabel: label,
      ),
      tooltip: label,
    );
  }

  static IconData _iconFor(FlashMode mode) => switch (mode) {
        FlashMode.off => Icons.flash_off,
        FlashMode.auto => Icons.flash_auto,
        _ => Icons.flash_on, // always / torch
      };

  static String _labelFor(FlashMode mode) => switch (mode) {
        FlashMode.off => 'Flash Off',
        FlashMode.auto => 'Flash Auto',
        _ => 'Flash On',
      };
}
