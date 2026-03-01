import 'lab_color.dart';

/// Severity classification for a urine-analysis result level.
enum Severity {
  /// Within the expected reference range.
  normal,

  /// Mildly outside the reference range — warrants monitoring.
  borderline,

  /// Significantly outside the reference range.
  abnormal,

  /// Dangerously outside range — requires immediate medical attention.
  critical;

  /// Constructs a [Severity] from its string name (case-insensitive).
  static Severity fromString(String value) {
    return Severity.values.firstWhere(
      (s) => s.name.toLowerCase() == value.toLowerCase(),
      orElse: () => Severity.normal,
    );
  }
}

/// A single reference level for one parameter (e.g. "Trace (100 mg/dL)").
class ReferenceLevel {
  const ReferenceLevel({
    required this.label,
    required this.lab,
    required this.severity,
  });

  /// Human-readable label shown to the user (e.g. "Negative", "250 mg/dL").
  final String label;

  /// CIE LAB reference colour for this level.
  final LabColor lab;

  /// Severity classification.
  final Severity severity;

  /// Constructs a [ReferenceLevel] from JSON.
  ///
  /// Expects `lab` to be a list `[L, a, b]` and `severity` to be a string.
  factory ReferenceLevel.fromJson(Map<String, dynamic> json) {
    return ReferenceLevel(
      label: json['label'] as String,
      lab: LabColor.fromList(json['lab'] as List<dynamic>),
      severity: Severity.fromString(json['severity'] as String),
    );
  }

  /// Converts to a JSON-serialisable map.
  Map<String, dynamic> toJson() => {
        'label': label,
        'lab': [lab.l, lab.a, lab.b],
        'severity': severity.name,
      };

  @override
  String toString() => 'ReferenceLevel($label, ${severity.name})';
}

/// All reference levels for one urine-strip parameter (e.g. "Glucose").
class ParameterReference {
  const ParameterReference({
    required this.parameter,
    required this.normalRange,
    required this.clinicalSignificance,
    required this.levels,
  });

  /// Parameter name (e.g. "Glucose").
  final String parameter;

  /// Human-readable normal range (e.g. "Negative").
  final String normalRange;

  /// Brief clinical significance description.
  final String clinicalSignificance;

  /// Reference levels ordered from normal to most abnormal.
  final List<ReferenceLevel> levels;

  /// Constructs a [ParameterReference] from JSON.
  factory ParameterReference.fromJson(Map<String, dynamic> json) {
    final rawLevels = json['levels'] as List<dynamic>;
    return ParameterReference(
      parameter: json['parameter'] as String,
      normalRange: json['normalRange'] as String,
      clinicalSignificance: json['clinicalSignificance'] as String,
      levels: rawLevels
          .map((l) => ReferenceLevel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts to a JSON-serialisable map.
  Map<String, dynamic> toJson() => {
        'parameter': parameter,
        'normalRange': normalRange,
        'clinicalSignificance': clinicalSignificance,
        'levels': levels.map((l) => l.toJson()).toList(),
      };

  @override
  String toString() => 'ParameterReference($parameter, ${levels.length} levels)';
}
