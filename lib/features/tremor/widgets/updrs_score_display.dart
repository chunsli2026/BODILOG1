import 'package:flutter/material.dart';

import '../models/tremor_result.dart';

/// Large circular UPDRS score badge with severity label and description.
class UpdrsScoreDisplay extends StatelessWidget {
  const UpdrsScoreDisplay({super.key, required this.result});

  final TremorResult result;

  String _description(int score) {
    const descriptions = [
      'No tremor detected. Sensor readings are within normal range.',
      'Slight tremor barely perceptible. Monitor over time.',
      'Mild tremor (amplitude < 1 cm). Consult a healthcare provider.',
      'Moderate tremor (1–10 cm). Prompt medical evaluation recommended.',
      'Severe tremor (> 10 cm). Urgent medical evaluation recommended.',
    ];
    return descriptions.elementAtOrNull(score) ??
        'Unknown severity level.';
  }

  @override
  Widget build(BuildContext context) {
    final color = result.severityColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color, width: 4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${result.updrsScore}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'UPDRS',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          result.updrsLabel,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _description(result.updrsScore),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
