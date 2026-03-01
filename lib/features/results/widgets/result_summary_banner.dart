import 'package:flutter/material.dart';

import '../../analysis/models/test_result.dart';

/// Full-width banner showing the overall test status and normal-count summary.
class ResultSummaryBanner extends StatelessWidget {
  const ResultSummaryBanner({super.key, required this.testResult});

  /// The test result to summarise.
  final TestResult testResult;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _bannerColor(testResult.overallStatus);
    final IconData icon = _bannerIcon(testResult.overallStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: bgColor,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  testResult.summaryText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(testResult.overallStatus),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _bannerColor(String status) {
    switch (status) {
      case 'abnormal':
        return const Color(0xFF922B21);
      case 'attention_needed':
        return const Color(0xFFE67E22);
      default:
        return const Color(0xFF27AE60);
    }
  }

  IconData _bannerIcon(String status) {
    switch (status) {
      case 'abnormal':
        return Icons.error;
      case 'attention_needed':
        return Icons.warning_amber;
      default:
        return Icons.check_circle;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'abnormal':
        return 'Abnormal — consult a healthcare provider';
      case 'attention_needed':
        return 'Some parameters need attention';
      default:
        return 'All parameters within normal range';
    }
  }
}
