import 'package:flutter_test/flutter_test.dart';
import 'package:bodilog/features/analysis/models/analysis_result.dart';
import 'package:bodilog/features/analysis/models/color_reference.dart';
import 'package:bodilog/features/analysis/models/lab_color.dart';
import 'package:bodilog/features/analysis/models/test_result.dart';

AnalysisResult _makeResult({
  String name = 'Glucose',
  String level = 'Negative',
  Severity severity = Severity.normal,
  double deltaE = 1.0,
  double confidence = 0.95,
}) {
  return AnalysisResult(
    parameterName: name,
    detectedLevel: level,
    severity: severity,
    deltaE: deltaE,
    confidenceScore: confidence,
    measuredLab: const LabColor(l: 85.0, a: -5.0, b: 30.0),
    referenceLab: const LabColor(l: 85.0, a: -5.0, b: 30.0),
    normalRange: 'Negative',
    clinicalSignificance: 'Diabetes screening',
  );
}

void main() {
  group('AnalysisResult serialisation', () {
    test('toMap() and fromMap() round-trip', () {
      final result = _makeResult(deltaE: 3.5, confidence: 0.9);
      final map = result.toMap();
      final restored = AnalysisResult.fromMap(map);

      expect(restored.parameterName, equals(result.parameterName));
      expect(restored.detectedLevel, equals(result.detectedLevel));
      expect(restored.severity, equals(result.severity));
      expect(restored.deltaE, closeTo(result.deltaE, 1e-9));
      expect(restored.confidenceScore, closeTo(result.confidenceScore, 1e-9));
      expect(restored.measuredLab, equals(result.measuredLab));
      expect(restored.referenceLab, equals(result.referenceLab));
      expect(restored.normalRange, equals(result.normalRange));
      expect(restored.clinicalSignificance,
          equals(result.clinicalSignificance));
    });

    test('isLowConfidence is true when deltaE > 10', () {
      final r = _makeResult(deltaE: 10.1);
      expect(r.isLowConfidence, isTrue);
    });

    test('isLowConfidence is false when deltaE <= 10', () {
      final r = _makeResult(deltaE: 10.0);
      expect(r.isLowConfidence, isFalse);
    });
  });

  group('TestResult', () {
    final normal = _makeResult(severity: Severity.normal);
    final borderline =
        _makeResult(name: 'Protein', severity: Severity.borderline);
    final abnormal =
        _makeResult(name: 'Blood', severity: Severity.abnormal);
    final critical =
        _makeResult(name: 'Leukocytes', severity: Severity.critical);

    test('summaryText counts normal results', () {
      final tr = TestResult(
        timestamp: DateTime.now(),
        stripImagePath: '',
        stripLayoutName: 'standard_10',
        results: [normal, borderline, abnormal],
        overallStatus: 'abnormal',
      );
      expect(tr.normalCount, equals(1));
      expect(tr.totalCount, equals(3));
      expect(tr.summaryText, equals('1 of 3 parameters normal'));
    });

    test('calculateOverallStatus: all normal → "normal"', () {
      expect(TestResult.calculateOverallStatus([normal, normal]),
          equals('normal'));
    });

    test('calculateOverallStatus: borderline → "attention_needed"', () {
      expect(TestResult.calculateOverallStatus([normal, borderline]),
          equals('attention_needed'));
    });

    test('calculateOverallStatus: abnormal → "abnormal"', () {
      expect(TestResult.calculateOverallStatus([normal, borderline, abnormal]),
          equals('abnormal'));
    });

    test('calculateOverallStatus: critical → "abnormal"', () {
      expect(TestResult.calculateOverallStatus([normal, critical]),
          equals('abnormal'));
    });

    test('hasLowConfidenceResults reflects high ΔE results', () {
      final lowConf = _makeResult(deltaE: 15.0);
      final tr = TestResult(
        timestamp: DateTime.now(),
        stripImagePath: '',
        stripLayoutName: 'standard_10',
        results: [normal, lowConf],
        overallStatus: 'normal',
      );
      expect(tr.hasLowConfidenceResults, isTrue);
    });

    test('TestResult.fromMap round-trip', () {
      final tr = TestResult(
        id: 1,
        timestamp: DateTime.utc(2026, 3, 1, 12, 0, 0),
        stripImagePath: '/path/to/image.jpg',
        stripLayoutName: 'standard_10',
        results: [normal],
        overallStatus: 'normal',
      );
      final map = tr.toMap();
      final restored = TestResult.fromMap(map);

      expect(restored.id, equals(1));
      expect(restored.timestamp, equals(tr.timestamp));
      expect(restored.stripImagePath, equals(tr.stripImagePath));
      expect(restored.stripLayoutName, equals(tr.stripLayoutName));
      expect(restored.overallStatus, equals(tr.overallStatus));
      expect(restored.results.length, equals(1));
    });
  });
}
