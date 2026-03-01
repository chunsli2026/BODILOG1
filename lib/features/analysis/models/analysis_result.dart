import 'package:flutter/material.dart';

import 'color_reference.dart';
import 'lab_color.dart';

/// Result for a single urine-strip parameter after colour analysis.
class AnalysisResult {
  const AnalysisResult({
    required this.parameterName,
    required this.detectedLevel,
    required this.severity,
    required this.deltaE,
    required this.confidenceScore,
    required this.measuredLab,
    required this.referenceLab,
    required this.normalRange,
    required this.clinicalSignificance,
  });

  /// Parameter name (e.g. "Glucose").
  final String parameterName;

  /// Human-readable detected level (e.g. "Trace (100 mg/dL)").
  final String detectedLevel;

  /// Severity of the detected level.
  final Severity severity;

  /// ΔE₀₀ distance to the best-matching reference level (lower = more certain).
  final double deltaE;

  /// Confidence score forwarded from the image processing stage (0.0–1.0).
  final double confidenceScore;

  /// Measured CIE LAB colour from the test-strip pad.
  final LabColor measuredLab;

  /// Reference CIE LAB colour of the matched level.
  final LabColor referenceLab;

  /// Human-readable normal range for this parameter.
  final String normalRange;

  /// Brief clinical significance description.
  final String clinicalSignificance;

  // ---------------------------------------------------------------------------
  // Derived properties
  // ---------------------------------------------------------------------------

  /// Returns `true` when the colour match is uncertain (ΔE₀₀ > 10).
  bool get isLowConfidence => deltaE > 10.0;

  /// UI colour associated with [severity].
  Color get severityColor {
    switch (severity) {
      case Severity.normal:
        return const Color(0xFF27AE60);
      case Severity.borderline:
        return const Color(0xFFE67E22);
      case Severity.abnormal:
        return const Color(0xFFE74C3C);
      case Severity.critical:
        return const Color(0xFF922B21);
    }
  }

  /// UI icon associated with [severity].
  IconData get severityIcon {
    switch (severity) {
      case Severity.normal:
        return Icons.check_circle;
      case Severity.borderline:
        return Icons.warning_amber;
      case Severity.abnormal:
        return Icons.error;
      case Severity.critical:
        return Icons.dangerous;
    }
  }

  /// Human-readable severity label.
  String get severityLabel {
    switch (severity) {
      case Severity.normal:
        return 'Normal';
      case Severity.borderline:
        return 'Borderline';
      case Severity.abnormal:
        return 'Abnormal';
      case Severity.critical:
        return 'Critical';
    }
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Converts to a flat map suitable for SQLite storage.
  Map<String, dynamic> toMap() => {
        'parameter_name': parameterName,
        'detected_value': detectedLevel,
        'severity': severity.name,
        'delta_e': deltaE,
        'confidence_score': confidenceScore,
        'lab_l': measuredLab.l,
        'lab_a': measuredLab.a,
        'lab_b': measuredLab.b,
        'ref_lab_l': referenceLab.l,
        'ref_lab_a': referenceLab.a,
        'ref_lab_b': referenceLab.b,
        'normal_range': normalRange,
        'clinical_significance': clinicalSignificance,
      };

  /// Constructs an [AnalysisResult] from a SQLite row map.
  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    return AnalysisResult(
      parameterName: map['parameter_name'] as String,
      detectedLevel: map['detected_value'] as String,
      severity: Severity.fromString(map['severity'] as String),
      deltaE: (map['delta_e'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 0.0,
      measuredLab: LabColor(
        l: (map['lab_l'] as num?)?.toDouble() ?? 0.0,
        a: (map['lab_a'] as num?)?.toDouble() ?? 0.0,
        b: (map['lab_b'] as num?)?.toDouble() ?? 0.0,
      ),
      referenceLab: LabColor(
        l: (map['ref_lab_l'] as num?)?.toDouble() ?? 0.0,
        a: (map['ref_lab_a'] as num?)?.toDouble() ?? 0.0,
        b: (map['ref_lab_b'] as num?)?.toDouble() ?? 0.0,
      ),
      normalRange: (map['normal_range'] as String?) ?? '',
      clinicalSignificance: (map['clinical_significance'] as String?) ?? '',
    );
  }

  @override
  String toString() =>
      'AnalysisResult($parameterName: $detectedLevel, ΔE=${deltaE.toStringAsFixed(2)})';
}
