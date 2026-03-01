import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../../shared/database/database_helper.dart';
import '../models/analysis_result.dart';
import '../models/color_reference.dart';
import '../models/lab_color.dart';
import '../models/test_result.dart';

/// Input supplied by the image-processing module for a single pad.
class PadInput {
  const PadInput({
    required this.padIndex,
    required this.parameterName,
    required this.labValues,
    required this.confidenceScore,
  });

  /// Zero-based index of the pad on the strip.
  final int padIndex;

  /// Name of the parameter this pad measures (e.g. "Glucose").
  final String parameterName;

  /// CIE LAB colour measured from the pad.
  final LabColor labValues;

  /// Confidence of the pad colour extraction (0.0–1.0).
  final double confidenceScore;
}

/// Core service for CIE LAB colour matching and test-result management.
///
/// Uses the **ΔE₀₀** (Delta E 2000) formula as defined in CIE Technical
/// Report 142-2001 for perceptually uniform colour comparison.
class ColorAnalysisService {
  // ---------------------------------------------------------------------------
  // Delta E 2000
  // ---------------------------------------------------------------------------

  /// Calculates the ΔE₀₀ colour difference between two CIE LAB colours.
  ///
  /// Returns 0.0 for identical colours.  The result is always ≥ 0.
  double deltaE2000(LabColor lab1, LabColor lab2) {
    const double kL = 1.0;
    const double kC = 1.0;
    const double kH = 1.0;

    final double l1 = lab1.l;
    final double a1 = lab1.a;
    final double b1 = lab1.b;
    final double l2 = lab2.l;
    final double a2 = lab2.a;
    final double b2 = lab2.b;

    // Step 1 — Compute C*ab (CIELAB chroma) for each colour
    final double cAb1 = math.sqrt(a1 * a1 + b1 * b1);
    final double cAb2 = math.sqrt(a2 * a2 + b2 * b2);

    // Step 2 — Compute the mean C*ab and the G factor
    final double cAbBar = (cAb1 + cAb2) / 2.0;
    final double cAbBar7 = math.pow(cAbBar, 7).toDouble();
    final double g =
        0.5 * (1.0 - math.sqrt(cAbBar7 / (cAbBar7 + 6103515625.0))); // 25^7

    // Step 3 — Compute a' (adjusted a*)
    final double aPrime1 = a1 * (1.0 + g);
    final double aPrime2 = a2 * (1.0 + g);

    // Step 4 — Compute C' and h' for each colour
    final double cPrime1 = math.sqrt(aPrime1 * aPrime1 + b1 * b1);
    final double cPrime2 = math.sqrt(aPrime2 * aPrime2 + b2 * b2);

    double hPrime1 = _atan2Degrees(b1, aPrime1);
    double hPrime2 = _atan2Degrees(b2, aPrime2);

    // Step 5 — Compute ΔL', ΔC', Δh', ΔH'
    final double deltaLPrime = l2 - l1;
    final double deltaCPrime = cPrime2 - cPrime1;

    double deltahPrime;
    if (cPrime1 * cPrime2 == 0.0) {
      deltahPrime = 0.0;
    } else {
      deltahPrime = hPrime2 - hPrime1;
      if (deltahPrime > 180.0) {
        deltahPrime -= 360.0;
      } else if (deltahPrime < -180.0) {
        deltahPrime += 360.0;
      }
    }

    final double deltaHPrime =
        2.0 * math.sqrt(cPrime1 * cPrime2) * _sinDegrees(deltahPrime / 2.0);

    // Step 6 — Compute mean values L̄', C̄', H̄'
    final double lPrimeBar = (l1 + l2) / 2.0;
    final double cPrimeBar = (cPrime1 + cPrime2) / 2.0;

    double hPrimeBar;
    if (cPrime1 * cPrime2 == 0.0) {
      hPrimeBar = hPrime1 + hPrime2;
    } else {
      final double diff = (hPrime1 - hPrime2).abs();
      if (diff <= 180.0) {
        hPrimeBar = (hPrime1 + hPrime2) / 2.0;
      } else if (hPrime1 + hPrime2 < 360.0) {
        hPrimeBar = (hPrime1 + hPrime2 + 360.0) / 2.0;
      } else {
        hPrimeBar = (hPrime1 + hPrime2 - 360.0) / 2.0;
      }
    }

    // Step 7 — Compute T
    final double t = 1.0
        - 0.17 * _cosDegrees(hPrimeBar - 30.0)
        + 0.24 * _cosDegrees(2.0 * hPrimeBar)
        + 0.32 * _cosDegrees(3.0 * hPrimeBar + 6.0)
        - 0.20 * _cosDegrees(4.0 * hPrimeBar - 63.0);

    // Step 8 — Compute SL, SC, SH
    final double lPrimeBarMinus50Sq =
        (lPrimeBar - 50.0) * (lPrimeBar - 50.0);
    final double sL = 1.0 +
        0.015 * lPrimeBarMinus50Sq / math.sqrt(20.0 + lPrimeBarMinus50Sq);
    final double sC = 1.0 + 0.045 * cPrimeBar;
    final double sH = 1.0 + 0.015 * cPrimeBar * t;

    // Step 9 — Compute RC and RT
    final double cPrimeBar7 = math.pow(cPrimeBar, 7).toDouble();
    final double rC =
        2.0 * math.sqrt(cPrimeBar7 / (cPrimeBar7 + 6103515625.0));
    final double deltaTheta =
        30.0 * math.exp(-math.pow((hPrimeBar - 275.0) / 25.0, 2).toDouble());
    final double rT = -math.sin(_toRadians(2.0 * deltaTheta)) * rC;

    // Step 10 — Compute ΔE₀₀
    final double lTerm = deltaLPrime / (kL * sL);
    final double cTerm = deltaCPrime / (kC * sC);
    final double hTerm = deltaHPrime / (kH * sH);

    return math
        .sqrt(lTerm * lTerm + cTerm * cTerm + hTerm * hTerm + rT * cTerm * hTerm);
  }

  // ---------------------------------------------------------------------------
  // Colour matching
  // ---------------------------------------------------------------------------

  /// Matches [padColor] against the levels in [reference] and returns the
  /// best-matching [AnalysisResult].
  AnalysisResult matchColor(LabColor padColor, ParameterReference reference) {
    if (reference.levels.isEmpty) {
      throw ArgumentError(
          'ParameterReference for ${reference.parameter} has no levels.');
    }

    ReferenceLevel bestLevel = reference.levels.first;
    double bestDeltaE = deltaE2000(padColor, reference.levels.first.lab);

    for (final level in reference.levels.skip(1)) {
      final double de = deltaE2000(padColor, level.lab);
      if (de < bestDeltaE) {
        bestDeltaE = de;
        bestLevel = level;
      }
    }

    return AnalysisResult(
      parameterName: reference.parameter,
      detectedLevel: bestLevel.label,
      severity: bestLevel.severity,
      deltaE: bestDeltaE,
      confidenceScore: 1.0, // overridden by caller when PadInput is available
      measuredLab: padColor,
      referenceLab: bestLevel.lab,
      normalRange: reference.normalRange,
      clinicalSignificance: reference.clinicalSignificance,
    );
  }

  // ---------------------------------------------------------------------------
  // Strip analysis
  // ---------------------------------------------------------------------------

  /// Analyses all pads from a test strip against the named reference chart.
  ///
  /// Returns a complete [TestResult] with all parameter results.
  Future<Result<TestResult>> analyzeStrip(
    List<PadInput> padInputs, {
    String referenceChart = 'standard_10',
  }) async {
    final chartsResult = await loadReferenceChart(referenceChart);
    if (chartsResult is AppError<List<ParameterReference>>) {
      return AppError(chartsResult.failure);
    }
    final references =
        (chartsResult as Success<List<ParameterReference>>).data;

    final Map<String, ParameterReference> refMap = {
      for (final r in references) r.parameter.toLowerCase(): r,
    };

    final List<AnalysisResult> analysisResults = [];

    for (final pad in padInputs) {
      final ref = refMap[pad.parameterName.toLowerCase()];
      if (ref == null) {
        return AppError(AnalysisFailure(
            'No reference data for parameter: ${pad.parameterName}'));
      }

      try {
        final result = matchColor(pad.labValues, ref);
        // Attach the confidence score from image processing
        analysisResults.add(AnalysisResult(
          parameterName: result.parameterName,
          detectedLevel: result.detectedLevel,
          severity: result.severity,
          deltaE: result.deltaE,
          confidenceScore: pad.confidenceScore,
          measuredLab: result.measuredLab,
          referenceLab: result.referenceLab,
          normalRange: result.normalRange,
          clinicalSignificance: result.clinicalSignificance,
        ));
      } catch (e) {
        return AppError(
            AnalysisFailure('Error analysing ${pad.parameterName}: $e'));
      }
    }

    final overallStatus = TestResult.calculateOverallStatus(analysisResults);

    final testResult = TestResult(
      timestamp: DateTime.now(),
      stripImagePath: '',
      stripLayoutName: referenceChart,
      results: analysisResults,
      overallStatus: overallStatus,
    );

    return Success(testResult);
  }

  // ---------------------------------------------------------------------------
  // Reference chart loading
  // ---------------------------------------------------------------------------

  /// Loads the named reference colour chart from the app bundle assets.
  ///
  /// [chartName] should be "standard_10" (without path or extension).
  Future<Result<List<ParameterReference>>> loadReferenceChart(
      String chartName) async {
    try {
      final String jsonString = await rootBundle
          .loadString('assets/color_references/${chartName}_references.json');
      final Map<String, dynamic> json =
          jsonDecode(jsonString) as Map<String, dynamic>;
      final List<dynamic> parametersJson = json['parameters'] as List<dynamic>;
      final references = parametersJson
          .map((p) => ParameterReference.fromJson(p as Map<String, dynamic>))
          .toList();
      return Success(references);
    } catch (e) {
      return AppError(
          AnalysisFailure('Failed to load reference chart "$chartName": $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Database — test results
  // ---------------------------------------------------------------------------

  /// Saves [result] to the local SQLite database in a transaction.
  ///
  /// Returns the new row ID on success.
  Future<Result<int>> saveTestResult(TestResult result) async {
    try {
      final db = await DatabaseHelper.instance.database;
      late int testId;

      await db.transaction((txn) async {
        testId = await txn.insert(
          'test_results',
          {
            'timestamp': result.timestamp.toIso8601String(),
            'strip_image_path': result.stripImagePath,
            'strip_layout_name': result.stripLayoutName,
            'overall_status': result.overallStatus,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final r in result.results) {
          await txn.insert(
            'parameter_results',
            {
              'test_id': testId,
              ...r.toMap(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      return Success(testId);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to save test result: $e'));
    }
  }

  /// Returns all stored test results, optionally filtered by date range.
  Future<Result<List<TestResult>>> getTestResults({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;

      String whereClause = '';
      final List<dynamic> whereArgs = [];

      if (startDate != null) {
        whereClause += 'timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final List<Map<String, dynamic>> testRows = await db.query(
        'test_results',
        where: whereClause.isEmpty ? null : whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'timestamp DESC',
      );

      final List<TestResult> testResults = [];
      for (final row in testRows) {
        final int id = row['id'] as int;
        final paramRows = await db.query(
          'parameter_results',
          where: 'test_id = ?',
          whereArgs: [id],
        );
        final analysisResults =
            paramRows.map((r) => AnalysisResult.fromMap(r)).toList();
        testResults.add(TestResult.fromMap(row, results: analysisResults));
      }

      return Success(testResults);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to retrieve test results: $e'));
    }
  }

  /// Returns the single most recent [TestResult], or `null` if none exist.
  Future<Result<TestResult?>> getLatestTestResult() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'test_results',
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.first;
      final int id = row['id'] as int;
      final paramRows = await db.query(
        'parameter_results',
        where: 'test_id = ?',
        whereArgs: [id],
      );
      final analysisResults =
          paramRows.map((r) => AnalysisResult.fromMap(r)).toList();
      return Success(TestResult.fromMap(row, results: analysisResults));
    } catch (e) {
      return AppError(
          DatabaseFailure('Failed to retrieve latest test result: $e'));
    }
  }

  /// Returns the [TestResult] with the given [id], or `null` if not found.
  Future<Result<TestResult?>> getTestResultById(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows =
          await db.query('test_results', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return const Success(null);

      final paramRows = await db.query(
        'parameter_results',
        where: 'test_id = ?',
        whereArgs: [id],
      );
      final analysisResults =
          paramRows.map((r) => AnalysisResult.fromMap(r)).toList();
      return Success(TestResult.fromMap(rows.first, results: analysisResults));
    } catch (e) {
      return AppError(
          DatabaseFailure('Failed to retrieve test result $id: $e'));
    }
  }

  /// Returns trend data for [parameterName] (most recent [maxResults] points).
  Future<Result<List<ParameterTrend>>> getParameterTrend(
    String parameterName, {
    int maxResults = 30,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT
          pr.parameter_name,
          tr.timestamp,
          pr.detected_value,
          pr.severity,
          pr.delta_e
        FROM parameter_results pr
        JOIN test_results tr ON pr.test_id = tr.id
        WHERE LOWER(pr.parameter_name) = LOWER(?)
        ORDER BY tr.timestamp DESC
        LIMIT ?
      ''', [parameterName, maxResults]);

      final trends = rows
          .map((r) => ParameterTrend(
                parameterName: r['parameter_name'] as String,
                timestamp: DateTime.parse(r['timestamp'] as String),
                detectedLevel: (r['detected_value'] as String?) ?? '',
                severity: Severity.fromString(
                    (r['severity'] as String?) ?? 'normal'),
                deltaE: (r['delta_e'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList();

      return Success(trends);
    } catch (e) {
      return AppError(
          DatabaseFailure('Failed to retrieve trend for $parameterName: $e'));
    }
  }

  /// Deletes the test result with [id] and all its parameter results.
  Future<Result<void>> deleteTestResult(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('parameter_results',
            where: 'test_id = ?', whereArgs: [id]);
        await txn.delete('test_results', where: 'id = ?', whereArgs: [id]);
      });
      return const Success(null);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to delete test result $id: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Private maths helpers
  // ---------------------------------------------------------------------------

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  static double _atan2Degrees(double y, double x) {
    double angle = math.atan2(y, x) * 180.0 / math.pi;
    if (angle < 0.0) angle += 360.0;
    return angle;
  }

  static double _sinDegrees(double degrees) => math.sin(_toRadians(degrees));

  static double _cosDegrees(double degrees) => math.cos(_toRadians(degrees));
}
