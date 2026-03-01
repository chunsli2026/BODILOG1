import 'package:flutter/material.dart';

/// Semi-transparent overlay with a rectangular cutout guide for aligning the
/// urine test strip during capture.
///
/// The guide occupies 70% of the screen width and uses a 1:4 aspect ratio
/// (width:height) appropriate for a standard test strip.
class CameraOverlayGuide extends StatelessWidget {
  const CameraOverlayGuide({
    super.key,
    this.isAligned = false,
  });

  /// When `true` the guide border turns green to indicate correct alignment.
  final bool isAligned;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(isAligned: isAligned),
      child: Align(
        alignment: const Alignment(0, -0.15),
        child: FractionallySizedBox(
          widthFactor: 0.7,
          child: AspectRatio(
            aspectRatio: 1 / 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Align the test strip within the guide',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.isAligned});

  final bool isAligned;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.45);

    // Guide rect: centred, 70 % width, 1:4 aspect ratio, shifted slightly up.
    final guideWidth = size.width * 0.70;
    final guideHeight = guideWidth * 4;
    final guideLeft = (size.width - guideWidth) / 2;
    final guideTop = (size.height - guideHeight) / 2 - size.height * 0.05;
    final guideRect = Rect.fromLTWH(guideLeft, guideTop, guideWidth, guideHeight);

    // Draw four surrounding overlay quadrants (leaving the guide area clear).
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width, guideTop), overlayPaint)
      ..drawRect(
        Rect.fromLTWH(0, guideTop + guideHeight, size.width,
            size.height - guideTop - guideHeight),
        overlayPaint,
      )
      ..drawRect(Rect.fromLTWH(0, guideTop, guideLeft, guideHeight), overlayPaint)
      ..drawRect(
        Rect.fromLTWH(
            guideLeft + guideWidth, guideTop, size.width - guideLeft - guideWidth, guideHeight),
        overlayPaint,
      );

    // Border around the guide.
    final borderPaint = Paint()
      ..color = isAligned ? Colors.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRect(guideRect, borderPaint);

    // Corner accent marks.
    const cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = isAligned ? Colors.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Top-left
    canvas
      ..drawLine(guideRect.topLeft, guideRect.topLeft.translate(cornerLength, 0), cornerPaint)
      ..drawLine(guideRect.topLeft, guideRect.topLeft.translate(0, cornerLength), cornerPaint)
      // Top-right
      ..drawLine(guideRect.topRight, guideRect.topRight.translate(-cornerLength, 0), cornerPaint)
      ..drawLine(guideRect.topRight, guideRect.topRight.translate(0, cornerLength), cornerPaint)
      // Bottom-left
      ..drawLine(
          guideRect.bottomLeft, guideRect.bottomLeft.translate(cornerLength, 0), cornerPaint)
      ..drawLine(
          guideRect.bottomLeft, guideRect.bottomLeft.translate(0, -cornerLength), cornerPaint)
      // Bottom-right
      ..drawLine(
          guideRect.bottomRight, guideRect.bottomRight.translate(-cornerLength, 0), cornerPaint)
      ..drawLine(
          guideRect.bottomRight, guideRect.bottomRight.translate(0, -cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned;
}
