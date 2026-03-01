import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';

/// A 2-D integer point used by the strip detection pipeline.
class StripPoint {
  final int x;
  final int y;

  const StripPoint(this.x, this.y);

  @override
  String toString() => 'StripPoint($x, $y)';
}

/// Service responsible for strip detection, auto-cropping, and perspective
/// correction.
class StripDetectorService {
  /// Detect the test strip in [sourceImage], crop to the bounding rectangle,
  /// and return the result.
  ///
  /// Returns [AnalysisFailure] when no strip region can be identified.
  Result<img.Image> detectAndCrop(img.Image sourceImage) {
    // Convert to greyscale for edge detection.
    final grey = img.grayscale(img.Image.from(sourceImage));

    // Apply Sobel edge detection to find edges.
    final edges = _sobelEdges(grey);

    // Threshold the edge image to get a binary mask.
    final binary = _threshold(edges, 40);

    // Find the largest rectangular contour approximating the strip.
    final corners = _findStripCorners(binary);
    if (corners == null) {
      return const AppError(
        AnalysisFailure(
          'No test strip detected in the image. Please retake the photo '
          'with the strip clearly visible and well-lit.',
        ),
      );
    }

    // Crop the image to the bounding box of the detected corners.
    final minX = corners.map((p) => p.x).reduce(math.min);
    final minY = corners.map((p) => p.y).reduce(math.min);
    final maxX = corners.map((p) => p.x).reduce(math.max);
    final maxY = corners.map((p) => p.y).reduce(math.max);

    final cropW = (maxX - minX).clamp(1, sourceImage.width - minX);
    final cropH = (maxY - minY).clamp(1, sourceImage.height - minY);

    final cropped = img.copyCrop(
      sourceImage,
      x: minX,
      y: minY,
      width: cropW,
      height: cropH,
    );

    return Success(cropped);
  }

  /// Apply a 4-point perspective warp to [croppedImage] using the supplied
  /// [corners] (top-left, top-right, bottom-right, bottom-left order).
  ///
  /// Produces a rectangular top-down view of the strip.
  Result<img.Image> correctPerspective(
    img.Image croppedImage,
    List<StripPoint> corners,
  ) {
    if (corners.length != 4) {
      return const AppError(
        AnalysisFailure('Perspective correction requires exactly 4 corner points.'),
      );
    }

    // Determine output size from the two longest sides.
    final tl = corners[0];
    final tr = corners[1];
    final br = corners[2];
    final bl = corners[3];

    final topWidth = _dist(tl, tr);
    final bottomWidth = _dist(bl, br);
    final leftHeight = _dist(tl, bl);
    final rightHeight = _dist(tr, br);

    final outW = math.max(topWidth, bottomWidth).round();
    final outH = math.max(leftHeight, rightHeight).round();

    if (outW <= 0 || outH <= 0) {
      return Success(croppedImage);
    }

    // Build the inverse perspective map (destination → source) and sample.
    final output = img.Image(width: outW, height: outH);

    // Source quadrilateral corners as doubles.
    final srcX = [tl.x, tr.x, br.x, bl.x].map((v) => v.toDouble()).toList();
    final srcY = [tl.y, tr.y, br.y, bl.y].map((v) => v.toDouble()).toList();

    for (var dy = 0; dy < outH; dy++) {
      for (var dx = 0; dx < outW; dx++) {
        final u = dx / outW;
        final v = dy / outH;

        // Bilinear interpolation of source coordinates.
        final sx = (1 - u) * (1 - v) * srcX[0] +
            u * (1 - v) * srcX[1] +
            u * v * srcX[2] +
            (1 - u) * v * srcX[3];
        final sy = (1 - u) * (1 - v) * srcY[0] +
            u * (1 - v) * srcY[1] +
            u * v * srcY[2] +
            (1 - u) * v * srcY[3];

        final px = sx.round().clamp(0, croppedImage.width - 1);
        final py = sy.round().clamp(0, croppedImage.height - 1);

        output.setPixel(dx, dy, croppedImage.getPixel(px, py));
      }
    }

    return Success(output);
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Sobel edge-magnitude image (greyscale input, greyscale output).
  img.Image _sobelEdges(img.Image grey) {
    final out = img.Image(width: grey.width, height: grey.height);

    for (var y = 1; y < grey.height - 1; y++) {
      for (var x = 1; x < grey.width - 1; x++) {
        final gx = -_luma(grey, x - 1, y - 1) +
            _luma(grey, x + 1, y - 1) +
            -2 * _luma(grey, x - 1, y) +
            2 * _luma(grey, x + 1, y) +
            -_luma(grey, x - 1, y + 1) +
            _luma(grey, x + 1, y + 1);

        final gy = -_luma(grey, x - 1, y - 1) +
            -2 * _luma(grey, x, y - 1) +
            -_luma(grey, x + 1, y - 1) +
            _luma(grey, x - 1, y + 1) +
            2 * _luma(grey, x, y + 1) +
            _luma(grey, x + 1, y + 1);

        final mag = math.sqrt(gx * gx + gy * gy).clamp(0, 255).toInt();
        out.setPixelRgba(x, y, mag, mag, mag, 255);
      }
    }
    return out;
  }

  /// Return the greyscale luma value (0–255) at (x, y).
  int _luma(img.Image grey, int x, int y) {
    return grey.getPixel(x, y).r.toInt();
  }

  /// Produce a binary image: pixels brighter than [threshold] become white.
  img.Image _threshold(img.Image src, int threshold) {
    final out = img.Image(width: src.width, height: src.height);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final v = src.getPixel(x, y).r.toInt();
        final c = v >= threshold ? 255 : 0;
        out.setPixelRgba(x, y, c, c, c, 255);
      }
    }
    return out;
  }

  /// Scan for the bounding-box corners of the largest bright (edge) region.
  ///
  /// Returns `null` if the detected region is implausibly small.
  List<StripPoint>? _findStripCorners(img.Image binary) {
    int minX = binary.width, minY = binary.height, maxX = 0, maxY = 0;
    int edgeCount = 0;

    for (var y = 0; y < binary.height; y++) {
      for (var x = 0; x < binary.width; x++) {
        if (binary.getPixel(x, y).r.toInt() > 128) {
          edgeCount++;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    // Require a minimum number of edge pixels and a minimum region size.
    final regionW = maxX - minX;
    final regionH = maxY - minY;
    final minDim = math.min(binary.width, binary.height);

    if (edgeCount < 100 || regionW < minDim * 0.1 || regionH < minDim * 0.1) {
      return null;
    }

    return [
      StripPoint(minX, minY),
      StripPoint(maxX, minY),
      StripPoint(maxX, maxY),
      StripPoint(minX, maxY),
    ];
  }

  double _dist(StripPoint a, StripPoint b) {
    final dx = (a.x - b.x).toDouble();
    final dy = (a.y - b.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }
}
