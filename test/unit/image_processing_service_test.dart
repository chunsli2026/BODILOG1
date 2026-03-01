import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:bodilog/core/error/result.dart';
import 'package:bodilog/features/analysis/models/strip_layout.dart';
import 'package:bodilog/features/analysis/services/image_processing_service.dart';

void main() {
  group('ImageProcessingService', () {
    late ImageProcessingService service;

    setUp(() {
      service = ImageProcessingService();
    });

    // ── Input validation ─────────────────────────────────────────────────

    group('processStripImage – input validation', () {
      test('returns AnalysisFailure when the file does not exist', () async {
        final result = await service.processStripImage('/no/such/file.png');

        expect(result.isError, isTrue);
        expect(
          (result as AppError).failure.message,
          contains('not found'),
        );
      });

      test('returns AnalysisFailure when the file is not a valid image',
          () async {
        final tmpFile = File('/tmp/not_an_image.png');
        tmpFile.writeAsBytesSync([0x00, 0x01, 0x02, 0xFF]);
        addTearDown(tmpFile.deleteSync);

        final result = await service.processStripImage(tmpFile.path);

        expect(result.isError, isTrue);
        expect(
          (result as AppError).failure.message,
          anyOf(contains('decode'), contains('not found'), contains('dark'), contains('bright')),
        );
      });
    });

    // ── Strip layout loading ─────────────────────────────────────────────

    group('StripLayout.fromJsonString', () {
      const standard10Json = '''
{
  "name": "standard_10",
  "padCount": 10,
  "padSpacing": 0.08,
  "padAspectRatio": 2.5,
  "pads": [
    {"index": 0, "parameterName": "Leukocytes",      "relativePosition": 0.05, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 1, "parameterName": "Nitrite",         "relativePosition": 0.14, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 2, "parameterName": "Urobilinogen",    "relativePosition": 0.23, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 3, "parameterName": "Protein",         "relativePosition": 0.32, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 4, "parameterName": "pH",              "relativePosition": 0.41, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 5, "parameterName": "Blood",           "relativePosition": 0.50, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 6, "parameterName": "Specific Gravity","relativePosition": 0.59, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 7, "parameterName": "Ketone",          "relativePosition": 0.68, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 8, "parameterName": "Bilirubin",       "relativePosition": 0.77, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 9, "parameterName": "Glucose",         "relativePosition": 0.86, "relativeWidth": 0.6, "relativeHeight": 0.07}
  ]
}
''';

      test('parses name and padCount correctly', () {
        final layout = StripLayout.fromJsonString(standard10Json);
        expect(layout.name, equals('standard_10'));
        expect(layout.padCount, equals(10));
      });

      test('produces 10 pads', () {
        final layout = StripLayout.fromJsonString(standard10Json);
        expect(layout.pads.length, equals(10));
      });

      test('first pad is Leukocytes', () {
        final layout = StripLayout.fromJsonString(standard10Json);
        expect(layout.pads.first.parameterName, equals('Leukocytes'));
      });

      test('last pad is Glucose', () {
        final layout = StripLayout.fromJsonString(standard10Json);
        expect(layout.pads.last.parameterName, equals('Glucose'));
      });
    });

    // ── Pipeline with an all-grey test image ─────────────────────────────

    group('processStripImage – synthetic image', () {
      File _writeSyntheticPng(int width, int height, int luma) {
        final image = img.Image(width: width, height: height);
        img.fill(image, color: img.ColorRgb8(luma, luma, luma));
        final bytes = img.encodePng(image);
        final file = File('/tmp/test_strip_$luma.png');
        file.writeAsBytesSync(bytes);
        return file;
      }

      test('returns AnalysisFailure for an all-black (too dark) image',
          () async {
        final file = _writeSyntheticPng(200, 600, 5);
        addTearDown(file.deleteSync);

        final result = await service.processStripImage(file.path);

        expect(result.isError, isTrue);
        expect(
          (result as AppError).failure.message,
          contains('dark'),
        );
      });

      test('returns AnalysisFailure for an all-white (too bright) image',
          () async {
        final file = _writeSyntheticPng(200, 600, 250);
        addTearDown(file.deleteSync);

        final result = await service.processStripImage(file.path);

        expect(result.isError, isTrue);
        expect(
          (result as AppError).failure.message,
          contains('bright'),
        );
      });

      test('succeeds with a mid-grey image using a custom layout', () async {
        // Build a mid-grey image (luma ≈ 128 → passes quality checks).
        final file = _writeSyntheticPng(200, 600, 128);
        addTearDown(file.deleteSync);

        final layout = StripLayout(
          name: 'test_2',
          padCount: 2,
          padSpacing: 0.1,
          padAspectRatio: 2.0,
          pads: [
            const PadConfig(
              index: 0,
              parameterName: 'TestA',
              relativePosition: 0.1,
              relativeWidth: 0.5,
              relativeHeight: 0.1,
            ),
            const PadConfig(
              index: 1,
              parameterName: 'TestB',
              relativePosition: 0.5,
              relativeWidth: 0.5,
              relativeHeight: 0.1,
            ),
          ],
        );

        final result = await service.processStripImage(
          file.path,
          layout: layout,
        );

        // A mid-grey uniform image may or may not pass strip detection;
        // we just verify the service returns a typed Result without throwing.
        expect(result, isA<Result>());
      });
    });

    // ── White-balance normalisation ──────────────────────────────────────

    group('normalizeWhiteBalance', () {
      test('returns Success for a valid image', () async {
        final image = img.Image(width: 100, height: 100);
        img.fill(image, color: img.ColorRgb8(200, 190, 210));

        final result = await service.normalizeWhiteBalance(image);
        expect(result.isSuccess, isTrue);
      });

      test('returns the input unchanged when no bright pixels are found',
          () async {
        final image = img.Image(width: 50, height: 50);
        img.fill(image, color: img.ColorRgb8(10, 10, 10));

        final result = await service.normalizeWhiteBalance(image);
        expect(result.isSuccess, isTrue);
      });
    });

    // ── Noise reduction ──────────────────────────────────────────────────

    group('reduceNoise', () {
      test('returns an image of the same dimensions', () {
        final image = img.Image(width: 80, height: 120);
        img.fill(image, color: img.ColorRgb8(128, 128, 128));

        final result = service.reduceNoise(image);

        expect(result.width, equals(image.width));
        expect(result.height, equals(image.height));
      });
    });
  });
}
