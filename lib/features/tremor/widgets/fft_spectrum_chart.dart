import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/tremor_result.dart';

/// Frequency spectrum (FFT) chart with tremor-band overlay.
///
/// Highlights the 3–7 Hz Parkinsonian tremor band and marks the
/// dominant frequency with a vertical indicator.
class FftSpectrumChart extends StatelessWidget {
  const FftSpectrumChart({
    super.key,
    required this.fftResult,
    required this.dominantFrequencyHz,
    this.maxFreqHz = 15.0,
  });

  /// FFT data to display.
  final FftResult fftResult;

  /// Dominant tremor frequency to mark with a vertical line.
  final double dominantFrequencyHz;

  /// Maximum frequency shown on the x-axis.
  final double maxFreqHz;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < fftResult.frequencies.length; i++) {
      final f = fftResult.frequencies[i];
      if (f <= maxFreqHz) {
        spots.add(FlSpot(f, fftResult.amplitudes[i]));
      }
    }

    final maxAmp = fftResult.amplitudes.isEmpty
        ? 1.0
        : fftResult.amplitudes.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxFreqHz,
        minY: 0,
        maxY: maxAmp * 1.1,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Frequency (Hz)',
                style: TextStyle(fontSize: 11)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Amplitude',
                style: TextStyle(fontSize: 11)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(2),
                style: const TextStyle(fontSize: 9),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        // Tremor band overlay (3–7 Hz) and dominant frequency line.
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (dominantFrequencyHz > 0)
              VerticalLine(
                x: dominantFrequencyHz,
                color: Colors.red,
                strokeWidth: 1.5,
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (line) =>
                      '${line.x.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                      color: Colors.red, fontSize: 10),
                ),
              ),
          ],
        ),
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            VerticalRangeAnnotation(
              x1: 3.0,
              x2: 7.0,
              color: Colors.orange.withOpacity(0.15),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
            isCurved: false,
            color: const Color(0xFF1A5276),
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
