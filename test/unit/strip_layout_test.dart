import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/analysis/models/strip_layout.dart';

void main() {
  // ── Shared fixtures ────────────────────────────────────────────────────

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

  const extended14Json = '''
{
  "name": "extended_14",
  "padCount": 14,
  "padSpacing": 0.06,
  "padAspectRatio": 2.5,
  "pads": [
    {"index": 0,  "parameterName": "Leukocytes",      "relativePosition": 0.05, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 1,  "parameterName": "Nitrite",         "relativePosition": 0.14, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 2,  "parameterName": "Urobilinogen",    "relativePosition": 0.23, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 3,  "parameterName": "Protein",         "relativePosition": 0.32, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 4,  "parameterName": "pH",              "relativePosition": 0.41, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 5,  "parameterName": "Blood",           "relativePosition": 0.50, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 6,  "parameterName": "Specific Gravity","relativePosition": 0.59, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 7,  "parameterName": "Ketone",          "relativePosition": 0.68, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 8,  "parameterName": "Bilirubin",       "relativePosition": 0.77, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 9,  "parameterName": "Glucose",         "relativePosition": 0.86, "relativeWidth": 0.6, "relativeHeight": 0.07},
    {"index": 10, "parameterName": "Ascorbic Acid",   "relativePosition": 0.90, "relativeWidth": 0.6, "relativeHeight": 0.05},
    {"index": 11, "parameterName": "Creatinine",      "relativePosition": 0.93, "relativeWidth": 0.6, "relativeHeight": 0.05},
    {"index": 12, "parameterName": "Calcium",         "relativePosition": 0.96, "relativeWidth": 0.6, "relativeHeight": 0.05},
    {"index": 13, "parameterName": "Microalbumin",    "relativePosition": 0.99, "relativeWidth": 0.6, "relativeHeight": 0.05}
  ]
}
''';

  // ── Standard 10-pad layout ─────────────────────────────────────────────

  group('StripLayout.fromJson – standard_10', () {
    late StripLayout layout;

    setUp(() {
      layout = StripLayout.fromJsonString(standard10Json);
    });

    test('name is "standard_10"', () {
      expect(layout.name, equals('standard_10'));
    });

    test('padCount is 10', () {
      expect(layout.padCount, equals(10));
    });

    test('pads list contains exactly 10 entries', () {
      expect(layout.pads.length, equals(10));
    });

    test('padSpacing is 0.08', () {
      expect(layout.padSpacing, closeTo(0.08, 0.001));
    });

    test('padAspectRatio is 2.5', () {
      expect(layout.padAspectRatio, closeTo(2.5, 0.001));
    });

    test('first pad is Leukocytes at index 0', () {
      expect(layout.pads[0].index, equals(0));
      expect(layout.pads[0].parameterName, equals('Leukocytes'));
    });

    test('last pad is Glucose at index 9', () {
      expect(layout.pads[9].index, equals(9));
      expect(layout.pads[9].parameterName, equals('Glucose'));
    });

    test('all pads have relativeWidth == 0.6', () {
      for (final pad in layout.pads) {
        expect(pad.relativeWidth, closeTo(0.6, 0.001));
      }
    });
  });

  // ── Extended 14-pad layout ─────────────────────────────────────────────

  group('StripLayout.fromJson – extended_14', () {
    late StripLayout layout;

    setUp(() {
      layout = StripLayout.fromJsonString(extended14Json);
    });

    test('name is "extended_14"', () {
      expect(layout.name, equals('extended_14'));
    });

    test('padCount is 14', () {
      expect(layout.padCount, equals(14));
    });

    test('pads list contains exactly 14 entries', () {
      expect(layout.pads.length, equals(14));
    });

    test('pad at index 10 is Ascorbic Acid', () {
      expect(layout.pads[10].parameterName, equals('Ascorbic Acid'));
    });

    test('pad at index 13 is Microalbumin', () {
      expect(layout.pads[13].parameterName, equals('Microalbumin'));
    });
  });

  // ── Serialisation round-trip ───────────────────────────────────────────

  group('StripLayout toJson / fromJson round-trip', () {
    test('standard_10 round-trip preserves all fields', () {
      final original = StripLayout.fromJsonString(standard10Json);
      final restored = StripLayout.fromJson(original.toJson());

      expect(restored.name, equals(original.name));
      expect(restored.padCount, equals(original.padCount));
      expect(restored.padSpacing, closeTo(original.padSpacing, 0.0001));
      expect(restored.padAspectRatio, closeTo(original.padAspectRatio, 0.0001));
      expect(restored.pads.length, equals(original.pads.length));

      for (var i = 0; i < original.pads.length; i++) {
        expect(restored.pads[i].index, equals(original.pads[i].index));
        expect(
          restored.pads[i].parameterName,
          equals(original.pads[i].parameterName),
        );
        expect(
          restored.pads[i].relativePosition,
          closeTo(original.pads[i].relativePosition, 0.0001),
        );
      }
    });

    test('JSON output is valid JSON', () {
      final layout = StripLayout.fromJsonString(standard10Json);
      final jsonString = jsonEncode(layout.toJson());
      expect(() => jsonDecode(jsonString), returnsNormally);
    });
  });
}
