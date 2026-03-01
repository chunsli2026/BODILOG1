import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/tremor_session.dart';
import '../providers/tremor_providers.dart';
import 'tremor_results_screen.dart';

/// Screen showing past tremor recording sessions and a trend chart.
class TremorHistoryScreen extends ConsumerWidget {
  const TremorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(tremorSessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tremor History')),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load history: $e')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Text(
                  'No tremor analysis sessions recorded yet.'),
            );
          }
          return Column(
            children: [
              // Trend chart.
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 200,
                  child: _TrendChart(sessions: sessions),
                ),
              ),
              const Divider(),
              // Session list.
              Expanded(
                child: ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    return _SessionTile(session: s);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.sessions});
  final List<TremorSession> sessions;

  @override
  Widget build(BuildContext context) {
    final reversed = sessions.reversed.toList();
    final spots = <FlSpot>[];
    for (var i = 0; i < reversed.length; i++) {
      spots.add(FlSpot(
          i.toDouble(), reversed[i].result.updrsScore.toDouble()));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 4,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= reversed.length) {
                  return const SizedBox.shrink();
                }
                final date = reversed[idx].timestamp;
                return Text(
                  DateFormat('M/d').format(date),
                  style: const TextStyle(fontSize: 9),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF1A5276),
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) {
                final idx = spot.x.toInt();
                final session = reversed[idx];
                return FlDotCirclePainter(
                  radius: 5,
                  color: session.result.scoreColor,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final TremorSession session;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d, yyyy HH:mm').format(session.timestamp);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: session.result.scoreColor,
        child: Text(
          '${session.result.updrsScore}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(dateStr),
      subtitle: Text(
        '${session.result.updrsLabel} • '
        '${session.result.dominantFrequencyHz.toStringAsFixed(1)} Hz • '
        '${session.durationSeconds}s',
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TremorResultsScreen(session: session),
        ),
      ),
    );
  }
}
