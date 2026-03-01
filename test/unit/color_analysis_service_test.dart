import 'package:flutter_test/flutter_test.dart';
import 'package:bodilog/features/analysis/models/lab_color.dart';
import 'package:bodilog/features/analysis/models/color_reference.dart';
import 'package:bodilog/features/analysis/services/color_analysis_service.dart';

void main() {
  final service = ColorAnalysisService();

  group('ColorAnalysisService.deltaE2000', () {
    test('identical colours return 0.0', () {
      const color = LabColor(l: 50.0, a: 25.0, b: -30.0);
      expect(service.deltaE2000(color, color), closeTo(0.0, 1e-10));
    });

    test('is symmetric: deltaE2000(a, b) == deltaE2000(b, a)', () {
      const c1 = LabColor(l: 50.0, a: 25.0, b: -30.0);
      const c2 = LabColor(l: 70.0, a: -10.0, b: 20.0);
      final de12 = service.deltaE2000(c1, c2);
      final de21 = service.deltaE2000(c2, c1);
      expect(de12, closeTo(de21, 1e-10));
    });

    test('very different colours produce large ΔE₀₀ (> 50)', () {
      const white = LabColor(l: 100.0, a: 0.0, b: 0.0);
      const black = LabColor(l: 0.0, a: 0.0, b: 0.0);
      expect(service.deltaE2000(white, black), greaterThan(50.0));
    });

    test('similar colours produce small ΔE₀₀ (< 5)', () {
      const c1 = LabColor(l: 50.0, a: 10.0, b: -5.0);
      const c2 = LabColor(l: 51.0, a: 10.5, b: -4.5);
      expect(service.deltaE2000(c1, c2), lessThan(5.0));
    });

    // CIE standard test pair (Sharma et al. 2005 test case #1)
    test('CIE published test pair #1 matches expected value', () {
      const c1 = LabColor(l: 50.0000, a: 2.6772, b: -79.7751);
      const c2 = LabColor(l: 50.0000, a: 0.0000, b: -82.7485);
      // Expected ΔE₀₀ ≈ 2.0425
      expect(service.deltaE2000(c1, c2), closeTo(2.0425, 0.0004));
    });

    // CIE standard test pair #2
    test('CIE published test pair #2 matches expected value', () {
      const c1 = LabColor(l: 50.0000, a: 3.1571, b: -77.2803);
      const c2 = LabColor(l: 50.0000, a: 0.0000, b: -82.7485);
      // Expected ΔE₀₀ ≈ 2.8615
      expect(service.deltaE2000(c1, c2), closeTo(2.8615, 0.0004));
    });
  });

  group('ColorAnalysisService.matchColor', () {
    final reference = ParameterReference(
      parameter: 'Glucose',
      normalRange: 'Negative',
      clinicalSignificance: 'Diabetes screening',
      levels: const [
        ReferenceLevel(
          label: 'Negative',
          lab: LabColor(l: 85.0, a: -5.0, b: 30.0),
          severity: Severity.normal,
        ),
        ReferenceLevel(
          label: 'Trace (100 mg/dL)',
          lab: LabColor(l: 75.0, a: -10.0, b: 40.0),
          severity: Severity.borderline,
        ),
        ReferenceLevel(
          label: '500 mg/dL',
          lab: LabColor(l: 55.0, a: -20.0, b: 50.0),
          severity: Severity.abnormal,
        ),
      ],
    );

    test('exact match returns ΔE₀₀ ≈ 0 and correct level', () {
      const padColor = LabColor(l: 85.0, a: -5.0, b: 30.0);
      final result = service.matchColor(padColor, reference);
      expect(result.detectedLevel, equals('Negative'));
      expect(result.deltaE, closeTo(0.0, 1e-10));
      expect(result.severity, equals(Severity.normal));
    });

    test('closest match is selected from multiple levels', () {
      // Close to the "Trace" level
      const padColor = LabColor(l: 74.5, a: -10.2, b: 39.8);
      final result = service.matchColor(padColor, reference);
      expect(result.detectedLevel, equals('Trace (100 mg/dL)'));
      expect(result.severity, equals(Severity.borderline));
    });

    test('low confidence flagged when ΔE₀₀ > 10', () {
      // Very different from all references
      const padColor = LabColor(l: 20.0, a: 60.0, b: -60.0);
      final result = service.matchColor(padColor, reference);
      expect(result.isLowConfidence, isTrue);
    });

    test('high confidence when ΔE₀₀ <= 10', () {
      const padColor = LabColor(l: 85.5, a: -5.1, b: 30.1);
      final result = service.matchColor(padColor, reference);
      expect(result.isLowConfidence, isFalse);
    });
  });
}
