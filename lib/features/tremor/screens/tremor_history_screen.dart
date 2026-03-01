import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/tremor_session.dart';
import '../providers/tremor_providers.dart';

/// Lists past tremor sessions with a UPDRS-over-time trend chart.
class TremorHistoryScreen extends ConsumerWidget {
  const TremorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(tremorSessionsProvider);

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading sessions: $e')),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No tremor analysis sessions recorded.\n'
                'Connect a wearable sensor to get started.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _TrendChart(sessions: sessions),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) =>
                    _SessionTile(session: sessions[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.sessions});

  final List<TremorSession> sessions;

  @override
  Widget build(BuildContext context) {
    final analysed =
        sessions.where((s) => s.updrsScore != null).toList().reversed.toList();

    if (analysed.isEmpty) {
      return const Center(child: Text('No analysed sessions yet'));
    }

    final spots = <FlSpot>[
      for (var i = 0; i < analysed.length; i++)
        FlSpot(i.toDouble(), analysed[i].updrsScore!.toDouble()),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 4,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('UPDRS'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final TremorSession session;

  static final _fmt = DateFormat('MMM d, yyyy — HH:mm');

  @override
  Widget build(BuildContext context) {
    final score = session.updrsScore;
    final color = score != null
        ? _scoreColor(score)
        : Colors.grey;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Text(
          score?.toString() ?? '—',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(_fmt.format(session.timestamp)),
      subtitle: Text(
        '${session.dominantFrequency?.toStringAsFixed(1) ?? '—'} Hz  •  '
        '${session.durationSeconds} s',
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Color _scoreColor(int score) {
    switch (score) {
      case 0:
        return const Color(0xFF27AE60);
      case 1:
        return const Color(0xFFF1C40F);
      case 2:
        return const Color(0xFFE67E22);
      case 3:
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF922B21);
    }
  }
}
