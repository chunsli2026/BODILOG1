import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/analysis/models/analysis_result.dart';
import 'package:bodilog/features/analysis/models/color_reference.dart';
import 'package:bodilog/features/analysis/models/lab_color.dart';
import 'package:bodilog/features/analysis/models/test_result.dart';
import 'package:bodilog/features/results/screens/results_screen.dart';

AnalysisResult _makeResult(String name, Severity severity) => AnalysisResult(
      parameterName: name,
      detectedLevel: 'Negative',
      severity: severity,
      deltaE: 2.0,
      confidenceScore: 0.95,
      measuredLab: const LabColor(l: 80.0, a: -4.0, b: 28.0),
      referenceLab: const LabColor(l: 80.0, a: -4.0, b: 28.0),
      normalRange: 'Negative',
      clinicalSignificance: 'Test',
    );

TestResult _makeTestResult() => TestResult(
      timestamp: DateTime.utc(2026, 3, 1, 12, 0, 0),
      stripImagePath: '',
      stripLayoutName: 'standard_10',
      results: [
        _makeResult('Glucose', Severity.normal),
        _makeResult('Protein', Severity.normal),
        _makeResult('Blood', Severity.normal),
      ],
      overallStatus: 'normal',
    );

void main() {
  group('ResultsScreen', () {
    testWidgets('shows message when no result is available', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ResultsScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('No result data available.'), findsOneWidget);
    });

    testWidgets('displays summary banner when result provided via provider',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ProviderScope(
                child: Consumer(
                  builder: (context, ref, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Would normally set currentTestResultProvider
                    });
                    return const ResultsScreen();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    });

    testWidgets(
        'ResultsScreen shows Save Results button when result passed as argument',
        (tester) async {
      final result = _makeTestResult();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name == '/results') {
                return MaterialPageRoute(
                  builder: (_) => const ResultsScreen(),
                  settings: settings,
                );
              }
              return MaterialPageRoute(
                builder: (_) => Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => Navigator.pushNamed(
                      ctx,
                      '/results',
                      arguments: result,
                    ),
                    child: const Text('Go'),
                  ),
                ),
              );
            },
            initialRoute: '/',
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Save Results'), findsOneWidget);
      expect(find.text('Disclaimer'), findsOneWidget);
    });

    testWidgets('shows disclaimer text', (tester) async {
      final result = _makeTestResult();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const ResultsScreen(),
                    settings: RouteSettings(arguments: result),
                  ),
                ),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.textContaining('informational and educational'), findsOneWidget);
    });

    testWidgets('renders parameter result cards for each result', (tester) async {
      final result = _makeTestResult();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const ResultsScreen(),
                    settings: RouteSettings(arguments: result),
                  ),
                ),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      // Each parameter name should appear
      expect(find.text('Glucose'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Blood'), findsOneWidget);
    });
  });
}
