import 'dart:convert';

import 'analysis_result.dart';
import 'color_reference.dart';

/// Complete test result containing all parameter results for one test-strip scan.
class TestResult {
  const TestResult({
    this.id,
    required this.timestamp,
    required this.stripImagePath,
    required this.stripLayoutName,
    required this.results,
    required this.overallStatus,
  });

  /// Database row ID — `null` before the result has been saved.
  final int? id;

  /// When the test was performed.
  final DateTime timestamp;

  /// File-system path to the captured strip image.
  final String stripImagePath;

  /// Reference chart used (e.g. "standard_10").
  final String stripLayoutName;

  /// Individual analysis result for each parameter.
  final List<AnalysisResult> results;

  /// Overall status string: "normal", "attention_needed", or "abnormal".
  final String overallStatus;

  // ---------------------------------------------------------------------------
  // Derived properties
  // ---------------------------------------------------------------------------

  /// Number of results with [Severity.normal].
  int get normalCount =>
      results.where((r) => r.severity == Severity.normal).length;

  /// Total number of results.
  int get totalCount => results.length;

  /// Short summary text, e.g. "8 of 10 parameters normal".
  String get summaryText => '$normalCount of $totalCount parameters normal';

  /// Returns `true` when at least one result has a low-confidence match.
  bool get hasLowConfidenceResults => results.any((r) => r.isLowConfidence);

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  /// Calculates the overall status from a list of [AnalysisResult]s.
  ///
  /// Rules (most severe wins):
  /// - Any critical → "abnormal"
  /// - Any abnormal → "abnormal"
  /// - Any borderline → "attention_needed"
  /// - All normal → "normal"
  static String calculateOverallStatus(List<AnalysisResult> results) {
    if (results.any((r) =>
        r.severity == Severity.critical || r.severity == Severity.abnormal)) {
      return 'abnormal';
    }
    if (results.any((r) => r.severity == Severity.borderline)) {
      return 'attention_needed';
    }
    return 'normal';
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Converts to a flat map for the `test_results` table row.
  ///
  /// Note: [results] are stored separately in `parameter_results`.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'timestamp': timestamp.toIso8601String(),
        'strip_image_path': stripImagePath,
        'strip_layout_name': stripLayoutName,
        'overall_status': overallStatus,
        // Embed results as JSON for convenience (also stored relationally).
        'results_json': jsonEncode(results.map((r) => r.toMap()).toList()),
      };

  /// Constructs a [TestResult] from a combined row map.
  ///
  /// Expects the map to contain either a `results_json` field **or** for
  /// [results] to be provided separately via [fromMapWithResults].
  factory TestResult.fromMap(Map<String, dynamic> map,
      {List<AnalysisResult>? results}) {
    List<AnalysisResult> parsedResults;
    if (results != null) {
      parsedResults = results;
    } else if (map['results_json'] != null) {
      final decoded =
          jsonDecode(map['results_json'] as String) as List<dynamic>;
      parsedResults = decoded
          .map((e) => AnalysisResult.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      parsedResults = const [];
    }

    return TestResult(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      stripImagePath: (map['strip_image_path'] as String?) ?? '',
      stripLayoutName: (map['strip_layout_name'] as String?) ?? 'standard_10',
      results: parsedResults,
      overallStatus: (map['overall_status'] as String?) ?? 'normal',
    );
  }

  @override
  String toString() =>
      'TestResult(id: $id, timestamp: $timestamp, $summaryText)';
}

/// Trend data for a single parameter at a single point in time.
class ParameterTrend {
  const ParameterTrend({
    required this.parameterName,
    required this.timestamp,
    required this.detectedLevel,
    required this.severity,
    required this.deltaE,
  });

  /// Parameter name (e.g. "Glucose").
  final String parameterName;

  /// When the measurement was taken.
  final DateTime timestamp;

  /// Detected level label.
  final String detectedLevel;

  /// Severity of the detected level.
  final Severity severity;

  /// ΔE₀₀ match quality.
  final double deltaE;

  /// Numeric severity index (0–3) suitable for a trend chart Y-axis.
  int get severityIndex => severity.index;
}
