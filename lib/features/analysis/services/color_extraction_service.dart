import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// A colour expressed in the CIE LAB (L*a*b*) perceptual colour space.
class LabColor {
  /// Lightness (0 = black, 100 = white).
  final double l;

  /// Green–red axis (negative = green, positive = red).
  final double a;

  /// Blue–yellow axis (negative = blue, positive = yellow).
  final double b;

  const LabColor({required this.l, required this.a, required this.b});

  /// Serialise to a plain map with keys `'L'`, `'a'`, `'b'`.
  Map<String, double> toMap() => {'L': l, 'a': a, 'b': b};

  /// Deserialise from a map produced by [toMap].
  factory LabColor.fromMap(Map<String, dynamic> map) {
    return LabColor(
      l: (map['L'] as num).toDouble(),
      a: (map['a'] as num).toDouble(),
      b: (map['b'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'LabColor(L: ${l.toStringAsFixed(2)}, '
      'a: ${a.toStringAsFixed(2)}, b: ${b.toStringAsFixed(2)})';
}

/// An intermediate colour expressed in the CIE XYZ colour space.
class XyzColor {
  final double x;
  final double y;
  final double z;

  const XyzColor({required this.x, required this.y, required this.z});
}

/// Service that extracts CIE LAB colour values from a pad image region.
///
/// Conversion path: RGB → linear-RGB → XYZ (sRGB matrix) → LAB (D65).
class ColorExtractionService {
  // D65 reference white point for the 2° observer.
  static const double _xn = 95.047;
  static const double _yn = 100.000;
  static const double _zn = 108.883;

  /// Extract the median L*a*b* values from the central [centralPercent]
  /// fraction of [padImage].
  ///
  /// The outer `(1 - centralPercent) / 2` border on each side is excluded to
  /// avoid contamination from the strip body or adjacent pads.
  LabColor extractMedianLab(img.Image padImage, {double centralPercent = 0.6}) {
    final pixels = _sampleCentralPixels(padImage, centralPercent);
    if (pixels.isEmpty) {
      return const LabColor(l: 0, a: 0, b: 0);
    }

    pixels.sort((a, b) => a.l.compareTo(b.l));
    final mid = pixels.length ~/ 2;

    // Use median for each channel independently to be robust to outliers.
    final lValues = pixels.map((p) => p.l).toList()..sort();
    final aValues = pixels.map((p) => p.a).toList()..sort();
    final bValues = pixels.map((p) => p.b).toList()..sort();

    return LabColor(
      l: lValues[mid],
      a: aValues[mid],
      b: bValues[mid],
    );
  }

  /// Calculate a colour-uniformity confidence score (0.0–1.0) for [padImage].
  ///
  /// High uniformity (low variance) → score close to 1.0.
  /// High variance → score close to 0.0.
  double calculateConfidence(
    img.Image padImage, {
    double centralPercent = 0.6,
  }) {
    final pixels = _sampleCentralPixels(padImage, centralPercent);
    if (pixels.length < 2) return 1.0;

    double sumL = 0, sumA = 0, sumB = 0;
    for (final p in pixels) {
      sumL += p.l;
      sumA += p.a;
      sumB += p.b;
    }
    final n = pixels.length.toDouble();
    final meanL = sumL / n;
    final meanA = sumA / n;
    final meanB = sumB / n;

    double varianceSum = 0;
    for (final p in pixels) {
      varianceSum +=
          math.pow(p.l - meanL, 2) +
          math.pow(p.a - meanA, 2) +
          math.pow(p.b - meanB, 2);
    }
    final variance = varianceSum / n;

    // Map variance to a 0–1 confidence score.  A variance of 0 gives 1.0;
    // a variance of 500 (approximate upper bound for LAB noise) gives ~0.0.
    const maxVariance = 500.0;
    return (1.0 - (variance / maxVariance)).clamp(0.0, 1.0);
  }

  /// Convert a single sRGB pixel to CIE LAB.
  LabColor rgbToLab(int r, int g, int b) {
    final xyz = rgbToXyz(r, g, b);
    return xyzToLab(xyz.x, xyz.y, xyz.z);
  }

  /// Convert an sRGB pixel (0–255 per channel) to CIE XYZ (D65).
  ///
  /// The conversion applies sRGB gamma removal then the standard 3 × 3 matrix.
  XyzColor rgbToXyz(int r, int g, int b) {
    // Normalise to 0–1.
    double rLin = _linearise(r / 255.0);
    double gLin = _linearise(g / 255.0);
    double bLin = _linearise(b / 255.0);

    // sRGB → XYZ (D65) matrix (IEC 61966-2-1).
    final x = rLin * 0.4124564 + gLin * 0.3575761 + bLin * 0.1804375;
    final y = rLin * 0.2126729 + gLin * 0.7151522 + bLin * 0.0721750;
    final z = rLin * 0.0193339 + gLin * 0.1191920 + bLin * 0.9503041;

    // Scale to the D65 reference white (×100).
    return XyzColor(x: x * 100, y: y * 100, z: z * 100);
  }

  /// Convert CIE XYZ (D65) to CIE LAB.
  LabColor xyzToLab(double x, double y, double z) {
    final fx = _labF(x / _xn);
    final fy = _labF(y / _yn);
    final fz = _labF(z / _zn);

    return LabColor(
      l: 116 * fy - 16,
      a: 500 * (fx - fy),
      b: 200 * (fy - fz),
    );
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Remove sRGB gamma (linearise) per IEC 61966-2-1.
  ///
  /// Constants: threshold 0.04045, slope 12.92, offset 0.055, gain 1.055,
  /// and exponent 2.4 are defined by the sRGB standard.
  double _linearise(double c) {
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// CIE LAB f() function as defined in CIE 15:2004 §8.2.1.2.
  ///
  /// Uses a cube-root with a linear segment near zero.
  /// δ = 6/29 is specified by the CIE standard; the linear slope
  /// 1/(3δ²) and intercept 4/29 ensure continuity and equal derivatives.
  double _labF(double t) {
    const delta = 6.0 / 29.0; // CIE standard constant
    return t > delta * delta * delta
        ? math.pow(t, 1.0 / 3.0).toDouble()
        : t / (3 * delta * delta) + 4.0 / 29.0;
  }

  /// Return LAB values for every pixel in the central [centralPercent] region.
  List<LabColor> _sampleCentralPixels(
    img.Image padImage,
    double centralPercent,
  ) {
    final border = (1.0 - centralPercent) / 2.0;
    final x0 = (padImage.width * border).round();
    final y0 = (padImage.height * border).round();
    final x1 = (padImage.width * (1.0 - border)).round();
    final y1 = (padImage.height * (1.0 - border)).round();

    if (x1 <= x0 || y1 <= y0) return [];

    final result = <LabColor>[];
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final pixel = padImage.getPixel(x, y);
        result.add(rgbToLab(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()));
      }
    }
    return result;
  }
}
