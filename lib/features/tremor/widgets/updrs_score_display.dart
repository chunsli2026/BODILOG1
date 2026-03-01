import 'package:flutter/material.dart';

import '../models/tremor_result.dart';

/// Displays a UPDRS tremor score (0–4) in a large coloured circle
/// with severity label and tremor-ratio percentage.
class UpdrsScoreDisplay extends StatelessWidget {
  const UpdrsScoreDisplay({
    super.key,
    required this.result,
    this.size = 120.0,
  });

  /// The tremor analysis result to visualise.
  final TremorResult result;

  /// Diameter of the score circle in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: result.scoreColor,
            boxShadow: [
              BoxShadow(
                color: result.scoreColor.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${result.updrsScore}',
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result.updrsLabel,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: result.scoreColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tremor ratio: ${(result.tremorRatio * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
