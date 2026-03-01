import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tremor_providers.dart';
import '../widgets/medical_disclaimer_dialog.dart';
import '../widgets/spectrum_chart.dart';
import '../widgets/updrs_score_display.dart';

/// Shows the latest tremor analysis results.
class TremorResultsScreen extends ConsumerWidget {
  const TremorResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(currentTremorResultProvider);

    if (result == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No analysis results yet.\nRecord a tremor session first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UpdrsScoreDisplay(result: result),
          const SizedBox(height: 24),
          Text(
            'Frequency Spectrum',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: SpectrumChart(result: result),
          ),
          const SizedBox(height: 24),
          _MetricsCard(result: result),
          const SizedBox(height: 16),
          const _DisclaimerBanner(),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.result});

  final TremorResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Metrics',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(),
            _MetricRow(
              label: 'Dominant frequency',
              value: '${result.dominantFrequency.toStringAsFixed(1)} Hz',
            ),
            _MetricRow(
              label: 'Tremor ratio',
              value:
                  '${(result.tremorRatio * 100).toStringAsFixed(1)}%',
            ),
            _MetricRow(
              label: 'Recording duration',
              value: '${result.durationSeconds} s',
            ),
            _MetricRow(
              label: 'Sampling rate',
              value:
                  '${result.samplingRate.toStringAsFixed(0)} Hz',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medical Disclaimer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This tool is for informational purposes only and is not '
                  'a medical device. Results are not a clinical diagnosis.',
                  style: TextStyle(fontSize: 12),
                ),
                TextButton(
                  onPressed: () =>
                      showMedicalDisclaimer(context, requireAcknowledgement: false),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Read full disclaimer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
