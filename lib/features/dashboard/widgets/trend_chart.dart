import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../analysis/models/test_result.dart';

/// A small card containing a line-chart for one parameter's severity over time.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.parameterName,
    required this.trends,
  });

  /// Name of the parameter (e.g. "Glucose").
  final String parameterName;

  /// Trend data points, most recent last (sorted ascending by timestamp).
  final List<ParameterTrend> trends;

  @override
  Widget build(BuildContext context) {
    final sorted = [...trends]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parameterName,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: sorted.length < 2
                  ? Center(
                      child: Text(
                        'Not enough data for trends',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _buildChart(context, sorted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<ParameterTrend> sorted) {
    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].severityIndex.toDouble()));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 3,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: (sorted.length / 3)
                  .ceilToDouble()
                  .clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= sorted.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  DateFormat('M/d').format(sorted[idx].timestamp),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
