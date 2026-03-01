import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/error/result.dart';
import '../models/tremor_result.dart';
import '../models/tremor_session.dart';
import '../providers/tremor_providers.dart';
import '../widgets/fft_spectrum_chart.dart';
import '../widgets/medical_disclaimer_dialog.dart';
import '../widgets/updrs_score_display.dart';

/// Displays the analysis results for a completed tremor recording session.
class TremorResultsScreen extends ConsumerWidget {
  const TremorResultsScreen({super.key, this.session});

  /// When non-null, shows results for a historical [TremorSession] instead of
  /// the current live result.
  final TremorSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveResult = ref.watch(currentTremorResultProvider);
    final result = session?.result ?? liveResult;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tremor Results')),
        body: const Center(child: Text('No result available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tremor Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Medical disclaimer (always visible on results screen).
            Card(
              color: AppTheme.warning.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  MedicalDisclaimerDialog.disclaimerText,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black87),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // UPDRS score.
            Center(child: UpdrsScoreDisplay(result: result)),

            const SizedBox(height: 24),

            // FFT spectrum.
            Text('Frequency Spectrum',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: FftSpectrumChart(
                fftResult: result.fftResult,
                dominantFrequencyHz: result.dominantFrequencyHz,
              ),
            ),

            const SizedBox(height: 16),

            // Details card.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recording Details',
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    _DetailRow(
                        label: 'Dominant Frequency',
                        value:
                            '${result.dominantFrequencyHz.toStringAsFixed(1)} Hz'),
                    _DetailRow(
                        label: 'Tremor Ratio',
                        value:
                            '${(result.tremorRatio * 100).toStringAsFixed(1)}%'),
                    _DetailRow(
                        label: 'Duration',
                        value:
                            '${result.recordingDuration.inSeconds}s'),
                    _DetailRow(
                        label: 'Sampling Rate',
                        value:
                            '${result.samplingRateHz.toStringAsFixed(0)} Hz'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Trend comparison.
            _TrendSection(currentResult: result),

            const SizedBox(height: 24),

            // Actions.
            if (session == null) ...[
              ElevatedButton(
                onPressed: () => _saveSession(context, ref, result),
                child: const Text('Save Session'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pushReplacementNamed(
                    context, '/tremor'),
                child: const Text('Record Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveSession(
      BuildContext context, WidgetRef ref, TremorResult result) async {
    final service = ref.read(tremorAnalysisServiceProvider);
    final buffer = ref.read(sensorBufferProvider);
    final sessionId =
        DateTime.now().millisecondsSinceEpoch.toString();
    final newSession = TremorSession(
      id: sessionId,
      deviceId: 'unknown',
      timestamp: DateTime.now(),
      durationSeconds: result.recordingDuration.inSeconds,
      samplingRateHz: result.samplingRateHz,
      result: result,
    );
    final saveResult = await service.saveSession(newSession);
    if (saveResult.isSuccess) {
      await service.saveRawData(sessionId, buffer.data);
      ref.invalidate(tremorSessionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session saved.')),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  (saveResult as AppError<void>).failure.message)),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection({required this.currentResult});
  final TremorResult currentResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(tremorSessionsProvider);
    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        final lastScore =
            sessions.first.result.updrsScore;
        final diff = currentResult.updrsScore - lastScore;
        final arrow = diff < 0 ? '↓' : diff > 0 ? '↑' : '→';
        final color = diff < 0
            ? AppTheme.success
            : diff > 0
                ? AppTheme.error
                : AppTheme.secondary;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('vs. last session: ',
                    style:
                        Theme.of(context).textTheme.bodyMedium),
                Text(
                  '$arrow ${diff.abs()} UPDRS',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
