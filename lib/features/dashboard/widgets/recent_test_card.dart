import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../analysis/models/test_result.dart';

/// Card showing a summary of the most recent test result.
class RecentTestCard extends StatelessWidget {
  const RecentTestCard({
    super.key,
    required this.testResult,
    required this.onTap,
  });

  /// The most recent test result to display.
  final TestResult testResult;

  /// Callback when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(testResult.overallStatus);
    final String dateStr =
        DateFormat('MMM d, yyyy • h:mm a').format(testResult.timestamp);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _statusIcon(testResult.overallStatus),
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testResult.summaryText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'abnormal':
        return AppTheme.error;
      case 'attention_needed':
        return AppTheme.warning;
      default:
        return AppTheme.success;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'abnormal':
        return Icons.error;
      case 'attention_needed':
        return Icons.warning_amber;
      default:
        return Icons.check_circle;
    }
  }
}
