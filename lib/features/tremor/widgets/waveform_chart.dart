import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Real-time scrolling accelerometer magnitude waveform.
///
/// Displays the last [windowSeconds] seconds of acceleration data as a
/// line chart with a green trace on a dark background.
class WaveformChart extends StatelessWidget {
  const WaveformChart({
    super.key,
    required this.data,
    required this.samplingRateHz,
    this.windowSeconds = 5.0,
  });

  /// Acceleration magnitude samples (m/s²), newest last.
  final List<double> data;

  /// Nominal sampling rate of the incoming data (Hz).
  final double samplingRateHz;

  /// Number of seconds visible in the scrolling window.
  final double windowSeconds;

  @override
  Widget build(BuildContext context) {
    final windowSamples = (windowSeconds * samplingRateHz).round();
    final visible = data.length > windowSamples
        ? data.sublist(data.length - windowSamples)
        : data;

    final spots = <FlSpot>[];
    for (var i = 0; i < visible.length; i++) {
      final tSec = i / samplingRateHz;
      spots.add(FlSpot(tSec, visible[i]));
    }

    double minY = 0;
    double maxY = 2;
    if (visible.isNotEmpty) {
      minY = visible.reduce((a, b) => a < b ? a : b) - 0.5;
      maxY = visible.reduce((a, b) => a > b ? a : b) + 0.5;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: windowSeconds,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFF2A2A3E), strokeWidth: 0.5),
            getDrawingVerticalLine: (_) =>
                const FlLine(color: Color(0xFF2A2A3E), strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Time (s)',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 9),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'm/s²',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 9),
                ),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots.isEmpty
                  ? [const FlSpot(0, 0)]
                  : spots,
              isCurved: false,
              color: const Color(0xFF2ECC71),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
