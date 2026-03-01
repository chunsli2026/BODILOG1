import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/tremor_result.dart';

/// FFT frequency-spectrum chart with the 3–7 Hz tremor band highlighted.
class SpectrumChart extends StatelessWidget {
  const SpectrumChart({super.key, required this.result});

  final TremorResult result;

  @override
  Widget build(BuildContext context) {
    final freqs = result.fftFrequencies;
    final amps = result.fftAmplitudes;

    if (freqs.isEmpty) return const Center(child: Text('No spectrum data'));

    final spots = <FlSpot>[
      for (var i = 0; i < freqs.length; i++) FlSpot(freqs[i], amps[i]),
    ];

    final maxAmp = amps.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 15,
        minY: 0,
        maxY: maxAmp * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            VerticalRangeAnnotation(
              x1: 3,
              x2: 7,
              color: Colors.orange.withOpacity(0.15),
            ),
          ],
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            VerticalLine(
              x: result.dominantFrequency,
              color: Colors.red,
              strokeWidth: 2,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (l) =>
                    '${result.dominantFrequency.toStringAsFixed(1)} Hz',
              ),
            ),
          ],
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Frequency (Hz)'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}', style: const TextStyle(fontSize: 10)),
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Amplitude'),
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
