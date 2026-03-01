import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Semi-transparent overlay painted over the camera preview.
///
/// Draws a darkened surround with a rectangular cutout guide that shows the
/// user where to position the urine test strip.  When [isAligned] is `true`
/// the border turns green to indicate correct placement.
class CameraOverlayGuide extends StatelessWidget {
  const CameraOverlayGuide({super.key, this.isAligned = false});

  /// Whether the strip appears to be correctly aligned (green border).
  final bool isAligned;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark overlay with a rectangular cutout for the guide zone.
        CustomPaint(
          painter: _OverlayPainter(isAligned: isAligned),
          child: const SizedBox.expand(),
        ),
        // Instruction text centred just below the guide rectangle.
        Align(
          alignment: const Alignment(0, 0.6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Align the test strip within the guide',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// [CustomPainter] that draws a semi-transparent dark overlay with a
/// rectangular cutout and a border around the guide area.
class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.isAligned});

  final bool isAligned;

  @override
  void paint(Canvas canvas, Size size) {
    // Guide rectangle: centred, ~70 % of screen width, strip aspect ratio.
    final guideWidth = size.width * 0.70;
    final guideHeight = guideWidth * 3.5;
    final guideLeft = (size.width - guideWidth) / 2;
    final guideTop = (size.height - guideHeight) / 2;

    final guideRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(guideLeft, guideTop, guideWidth, guideHeight),
      const Radius.circular(8),
    );

    // Dark overlay with even-odd fill to punch a hole in the guide zone.
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(guideRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, Paint()..color = Colors.black54);

    // Guide border.
    final borderColor = isAligned ? AppTheme.success : Colors.white70;
    canvas.drawRRect(
      guideRRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isAligned ? 3.0 : 2.0,
    );

    // Corner accent marks for a viewfinder feel.
    _drawCornerAccents(
      canvas,
      guideLeft,
      guideTop,
      guideWidth,
      guideHeight,
      borderColor,
    );
  }

  void _drawCornerAccents(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
    Color color,
  ) {
    const len = 20.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final r = left + width;
    final b = top + height;

    // Top-left
    canvas
      ..drawLine(Offset(left, top + len), Offset(left, top), paint)
      ..drawLine(Offset(left, top), Offset(left + len, top), paint)
      // Top-right
      ..drawLine(Offset(r - len, top), Offset(r, top), paint)
      ..drawLine(Offset(r, top), Offset(r, top + len), paint)
      // Bottom-left
      ..drawLine(Offset(left, b - len), Offset(left, b), paint)
      ..drawLine(Offset(left, b), Offset(left + len, b), paint)
      // Bottom-right
      ..drawLine(Offset(r - len, b), Offset(r, b), paint)
      ..drawLine(Offset(r, b), Offset(r, b - len), paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned;
}
