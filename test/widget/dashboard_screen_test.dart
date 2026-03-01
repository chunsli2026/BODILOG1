import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/dashboard/screens/dashboard_screen.dart';
import 'package:bodilog/features/analysis/models/test_result.dart';
import 'package:bodilog/features/results/providers/results_providers.dart';

Widget _buildDashboard({TestResult? latestResult}) {
  return ProviderScope(
    overrides: [
      latestTestResultProvider.overrideWith((_) async => latestResult),
      testResultsProvider.overrideWith((_) async =>
          latestResult != null ? [latestResult] : const <TestResult>[]),
      parameterTrendProvider.overrideWith((_, __) async => const []),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  );
}

void main() {
  group('DashboardScreen', () {
    testWidgets('shows empty state when no test results', (tester) async {
      await tester.pumpWidget(_buildDashboard());
      await tester.pump(); // trigger async
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining("No tests recorded"), findsOneWidget);
    });

    testWidgets('quick action buttons are present', (tester) async {
      await tester.pumpWidget(_buildDashboard());
      await tester.pumpAndSettle();
      expect(find.text('New Test'), findsOneWidget);
      expect(find.text('View Devices'), findsOneWidget);
      expect(find.text('Export Data'), findsOneWidget);
    });

    testWidgets('shows "Quick Actions" section header', (tester) async {
      await tester.pumpWidget(_buildDashboard());
      await tester.pumpAndSettle();
      expect(find.text('Quick Actions'), findsOneWidget);
    });
  });
}
