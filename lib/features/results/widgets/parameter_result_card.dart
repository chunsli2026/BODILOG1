import 'package:flutter/material.dart';

import '../../analysis/models/analysis_result.dart';

/// Card widget displaying the result for a single urine-strip parameter.
class ParameterResultCard extends StatelessWidget {
  const ParameterResultCard({super.key, required this.result});

  /// The analysis result to display.
  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity colour indicator
            Container(
              width: 6,
              height: 64,
              decoration: BoxDecoration(
                color: result.severityColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.parameterName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      // Severity badge
                      _SeverityBadge(result: result),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.detectedLevel,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: result.severityColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.clinicalSignificance,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Normal: ${result.normalRange}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey.shade500),
                  ),
                  if (result.isLowConfidence) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            size: 14, color: Color(0xFFE67E22)),
                        const SizedBox(width: 4),
                        Text(
                          'Low confidence',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFFE67E22),
                                    fontSize: 12,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: result.severityColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: result.severityColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(result.severityIcon, size: 12, color: result.severityColor),
          const SizedBox(width: 4),
          Text(
            result.severityLabel,
            style: TextStyle(
              color: result.severityColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
