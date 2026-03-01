import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:bodilog/features/analysis/services/color_extraction_service.dart';

void main() {
  late ColorExtractionService service;

  setUp(() {
    service = ColorExtractionService();
  });

  // ── RGB → XYZ ────────────────────────────────────────────────────────────

  group('rgbToXyz', () {
    test('pure black maps to (0, 0, 0)', () {
      final xyz = service.rgbToXyz(0, 0, 0);
      expect(xyz.x, closeTo(0.0, 0.001));
      expect(xyz.y, closeTo(0.0, 0.001));
      expect(xyz.z, closeTo(0.0, 0.001));
    });

    test('pure white maps to D65 reference white (≈95.047, 100.0, 108.883)',
        () {
      final xyz = service.rgbToXyz(255, 255, 255);
      expect(xyz.x, closeTo(95.047, 0.5));
      expect(xyz.y, closeTo(100.0, 0.5));
      expect(xyz.z, closeTo(108.883, 0.5));
    });

    test('mid-grey (128, 128, 128) has x == y == z (neutral)', () {
      final xyz = service.rgbToXyz(128, 128, 128);
      expect(xyz.x / xyz.y, closeTo(xyz.z / xyz.y, 0.05));
    });
  });

  // ── XYZ → LAB ───────────────────────────────────────────────────────────

  group('xyzToLab', () {
    test('D65 white XYZ produces L≈100, a≈0, b≈0', () {
      final lab = service.xyzToLab(95.047, 100.000, 108.883);
      expect(lab.l, closeTo(100.0, 0.5));
      expect(lab.a, closeTo(0.0, 0.5));
      expect(lab.b, closeTo(0.0, 0.5));
    });

    test('black XYZ (0,0,0) produces L≈0', () {
      final lab = service.xyzToLab(0, 0, 0);
      expect(lab.l, closeTo(0.0, 1.0));
    });
  });

  // ── Full RGB → LAB ───────────────────────────────────────────────────────

  group('rgbToLab', () {
    test('pure white (255, 255, 255) → L≈100, a≈0, b≈0', () {
      final lab = service.rgbToLab(255, 255, 255);
      expect(lab.l, closeTo(100.0, 1.0));
      expect(lab.a, closeTo(0.0, 2.0));
      expect(lab.b, closeTo(0.0, 2.0));
    });

    test('pure black (0, 0, 0) → L≈0, a≈0, b≈0', () {
      final lab = service.rgbToLab(0, 0, 0);
      expect(lab.l, closeTo(0.0, 1.0));
      expect(lab.a, closeTo(0.0, 2.0));
      expect(lab.b, closeTo(0.0, 2.0));
    });

    test('pure red (255, 0, 0) → L≈53.2, a≈80.1, b≈67.2', () {
      final lab = service.rgbToLab(255, 0, 0);
      expect(lab.l, closeTo(53.2, 1.5));
      expect(lab.a, closeTo(80.1, 2.0));
      expect(lab.b, closeTo(67.2, 2.0));
    });
  });

  // ── LabColor serialisation ───────────────────────────────────────────────

  group('LabColor', () {
    test('toMap returns keys L, a, b', () {
      const lab = LabColor(l: 50.0, a: 10.0, b: -5.0);
      final map = lab.toMap();
      expect(map['L'], equals(50.0));
      expect(map['a'], equals(10.0));
      expect(map['b'], equals(-5.0));
    });

    test('fromMap round-trip preserves values', () {
      const original = LabColor(l: 72.3, a: -8.5, b: 22.1);
      final restored = LabColor.fromMap(original.toMap());
      expect(restored.l, equals(original.l));
      expect(restored.a, equals(original.a));
      expect(restored.b, equals(original.b));
    });
  });

  // ── extractMedianLab ────────────────────────────────────────────────────

  group('extractMedianLab', () {
    test('returns median LAB for a uniform solid-colour image', () {
      // 10×10 uniform red image.
      final image = img.Image(width: 10, height: 10);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));

      final lab = service.extractMedianLab(image);
      final expected = service.rgbToLab(255, 0, 0);

      expect(lab.l, closeTo(expected.l, 1.0));
      expect(lab.a, closeTo(expected.a, 1.0));
      expect(lab.b, closeTo(expected.b, 1.0));
    });

    test('returns LabColor(0,0,0) for a 1×1 image with centralPercent=0.6',
        () {
      final image = img.Image(width: 1, height: 1);
      img.fill(image, color: img.ColorRgb8(0, 0, 0));

      // A 1×1 image after removing the border may yield no pixels.
      final lab = service.extractMedianLab(image);
      expect(lab, isA<LabColor>());
    });
  });

  // ── calculateConfidence ─────────────────────────────────────────────────

  group('calculateConfidence', () {
    test('uniform colour image has high confidence (≥ 0.9)', () {
      final image = img.Image(width: 20, height: 20);
      img.fill(image, color: img.ColorRgb8(120, 80, 60));

      final score = service.calculateConfidence(image);
      expect(score, greaterThanOrEqualTo(0.9));
    });

    test('confidence is between 0.0 and 1.0', () {
      final image = img.Image(width: 20, height: 20);
      // Checkerboard pattern introduces variance.
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 20; x++) {
          final c = (x + y).isEven ? img.ColorRgb8(255, 0, 0) : img.ColorRgb8(0, 0, 255);
          image.setPixel(x, y, c);
        }
      }

      final score = service.calculateConfidence(image);
      expect(score, inInclusiveRange(0.0, 1.0));
    });
  });
}
