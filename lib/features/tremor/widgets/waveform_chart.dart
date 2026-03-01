import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/sensor_data.dart';

/// Scrolling line chart that shows the last N seconds of acceleration
/// magnitude in real time.
class WaveformChart extends StatelessWidget {
  const WaveformChart({
    super.key,
    required this.samples,
    required this.samplingRate,
    this.windowSeconds = 5.0,
  });

  final List<SensorData> samples;
  final double samplingRate;

  /// Visible time window in seconds.
  final double windowSeconds;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const Center(child: Text('Waiting for sensor data…'));
    }

    final spots = <FlSpot>[];
    final maxSamples = (samplingRate * windowSeconds).ceil();
    final visible = samples.length > maxSamples
        ? samples.sublist(samples.length - maxSamples)
        : samples;

    for (var i = 0; i < visible.length; i++) {
      final t = i / samplingRate;
      spots.add(FlSpot(t, visible[i].accelMagnitude));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: windowSeconds,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Time (s)'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) =>
                  Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Accel (m/s²)'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) =>
                  Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}
