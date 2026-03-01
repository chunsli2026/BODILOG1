import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/error/result.dart';
import '../../analysis/models/test_result.dart';
import '../../analysis/services/color_analysis_service.dart';
import '../providers/results_providers.dart';
import '../widgets/parameter_result_card.dart';
import '../widgets/result_summary_banner.dart';

/// Screen that displays the full results of a urine test-strip analysis.
///
/// Can receive a [TestResult] via [RouteSettings.arguments] or will read it
/// from [currentTestResultProvider].
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _isSaving = false;
  bool _isSaved = false;

  TestResult? get _testResult {
    // Prefer argument passed via Navigator
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TestResult) return args;
    return ref.read(currentTestResultProvider);
  }

  Future<void> _saveResults(TestResult result) async {
    if (_isSaved) return;
    setState(() => _isSaving = true);

    final service = ref.read(colorAnalysisServiceProvider);
    final saveResult = await service.saveTestResult(result);

    setState(() => _isSaving = false);

    if (!mounted) return;
    if (saveResult.isSuccess) {
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results saved successfully')),
      );
    } else {
      final err = (saveResult as AppError).failure.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final testResult = _testResult;

    if (testResult == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: const Center(child: Text('No result data available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share results',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF export coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary banner
          ResultSummaryBanner(testResult: testResult),
          // Low-confidence warning
          if (testResult.hasLowConfidenceResults)
            Container(
              width: double.infinity,
              color: const Color(0xFFFEF9E7),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: Color(0xFFE67E22), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Some results have low confidence. Consider retaking '
                      'the photo with better lighting.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFE67E22),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          // Parameter result cards
          Expanded(
            child: ListView(
              children: [
                ...testResult.results
                    .map((r) => ParameterResultCard(result: r)),
                const SizedBox(height: 16),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaved || _isSaving
                              ? null
                              : () => _saveResults(testResult),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_isSaved ? Icons.check : Icons.save),
                          label: Text(_isSaved ? 'Saved' : 'Save Results'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('PDF export coming soon')),
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share Results'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Disclaimer
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.warning.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: AppTheme.warning, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Disclaimer',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppTheme.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This analysis is for informational and educational '
                        'purposes only. It is not a substitute for professional '
                        'medical diagnosis. Consult a healthcare provider for '
                        'medical advice.',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
