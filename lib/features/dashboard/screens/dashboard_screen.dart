import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../analysis/models/test_result.dart';
import '../../results/screens/results_screen.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_test_card.dart';
import '../widgets/trend_chart.dart';

/// Main dashboard screen showing recent results, trends, and quick actions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestTestResultProvider);
    final allResultsAsync = ref.watch(testResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BodiLog'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestTestResultProvider);
          ref.invalidate(testResultsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to BodiLog',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'AI-powered urine analysis and health monitoring',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Quick actions
              _SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              const QuickActions(),
              const SizedBox(height: 24),

              // Most recent result
              _SectionHeader(title: 'Most Recent Test'),
              const SizedBox(height: 12),
              latestAsync.when(
                data: (latest) => latest == null
                    ? _EmptyState(
                        message:
                            "No tests recorded. Tap 'New Test' to get started.")
                    : RecentTestCard(
                        testResult: latest,
                        onTap: () {
                          ref
                              .read(currentTestResultProvider.notifier)
                              .state = latest;
                          Navigator.pushNamed(context, '/results',
                              arguments: latest);
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    _EmptyState(message: 'Could not load recent test.'),
              ),
              const SizedBox(height: 24),

              // Trend charts
              _SectionHeader(title: 'Parameter Trends'),
              const SizedBox(height: 12),
              _TrendChartsSection(),
              const SizedBox(height: 24),

              // Past tests timeline
              _SectionHeader(title: 'Test History'),
              const SizedBox(height: 12),
              allResultsAsync.when(
                data: (results) => results.isEmpty
                    ? const _EmptyState(message: 'No test history yet.')
                    : _TestHistoryList(results: results),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    const _EmptyState(message: 'Could not load history.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChartsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
      ),
      itemCount: kDashboardTrendParameters.length,
      itemBuilder: (context, index) {
        final paramName = kDashboardTrendParameters[index];
        final trendsAsync = ref.watch(parameterTrendProvider(paramName));
        return trendsAsync.when(
          data: (trends) =>
              TrendChart(parameterName: paramName, trends: trends),
          loading: () => const Card(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) =>
              TrendChart(parameterName: paramName, trends: const []),
        );
      },
    );
  }
}

class _TestHistoryList extends ConsumerWidget {
  const _TestHistoryList({required this.results});

  final List<TestResult> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: results
          .take(10)
          .map((r) => _HistoryTile(
                testResult: r,
                onTap: () {
                  ref.read(currentTestResultProvider.notifier).state = r;
                  Navigator.pushNamed(context, '/results', arguments: r);
                },
              ))
          .toList(),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.testResult, required this.onTap});

  final TestResult testResult;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(testResult.overallStatus);
    final String dateStr =
        DateFormat('MMM d, yyyy • h:mm a').format(testResult.timestamp);

    return ListTile(
      leading: CircleAvatar(
        radius: 8,
        backgroundColor: statusColor,
      ),
      title: Text(testResult.summaryText),
      subtitle: Text(dateStr),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.grey.shade600),
      ),
    );
  }
}
