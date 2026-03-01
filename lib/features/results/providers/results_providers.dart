import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../analysis/models/test_result.dart';
import '../../analysis/services/color_analysis_service.dart';

/// Provides a single shared [ColorAnalysisService] instance.
final colorAnalysisServiceProvider = Provider<ColorAnalysisService>((ref) {
  return ColorAnalysisService();
});

/// Holds the [TestResult] currently being viewed (null when none is selected).
final currentTestResultProvider = StateProvider<TestResult?>((ref) => null);

/// Loads the most recent [TestResult] from the database (for the dashboard).
final latestTestResultProvider = FutureProvider<TestResult?>((ref) async {
  final service = ref.read(colorAnalysisServiceProvider);
  final result = await service.getLatestTestResult();
  return result is Success<TestResult?> ? result.data : null;
});

/// Loads all [TestResult]s from the database.
final testResultsProvider = FutureProvider<List<TestResult>>((ref) async {
  final service = ref.read(colorAnalysisServiceProvider);
  final result = await service.getTestResults();
  return result is Success<List<TestResult>> ? result.data : const [];
});

/// Loads trend data for the named parameter.
final parameterTrendProvider =
    FutureProvider.family<List<ParameterTrend>, String>(
        (ref, parameterName) async {
  final service = ref.read(colorAnalysisServiceProvider);
  final result = await service.getParameterTrend(parameterName);
  return result is Success<List<ParameterTrend>> ? result.data : const [];
});
