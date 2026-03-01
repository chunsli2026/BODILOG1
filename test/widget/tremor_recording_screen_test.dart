import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/tremor/providers/tremor_providers.dart';
import 'package:bodilog/features/tremor/screens/tremor_recording_screen.dart';
import 'package:bodilog/features/tremor/services/wearable_sensor_service.dart';

// ---------------------------------------------------------------------------
// Fake sensor service (never connected)
// ---------------------------------------------------------------------------

class _FakeSensorService extends WearableSensorService {
  @override
  bool get isConnected => false;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrapScreen({WearableSensorService? sensorService}) {
  return ProviderScope(
    overrides: [
      if (sensorService != null)
        wearableSensorServiceProvider
            .overrideWithValue(sensorService),
    ],
    child: const MaterialApp(
      home: TremorRecordingScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TremorRecordingScreen', () {
    testWidgets('"Start Recording" button is present', (tester) async {
      await tester.pumpWidget(
          _wrapScreen(sensorService: _FakeSensorService()));
      // Dismiss any dialogs that might appear (disclaimer).
      await tester.pumpAndSettle();

      expect(find.text('Start Recording'), findsOneWidget);
    });

    testWidgets('timer displays "00:00" initially', (tester) async {
      await tester.pumpWidget(
          _wrapScreen(sensorService: _FakeSensorService()));
      await tester.pumpAndSettle();

      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('minimum time indicator text is shown', (tester) async {
      await tester.pumpWidget(
          _wrapScreen(sensorService: _FakeSensorService()));
      await tester.pumpAndSettle();

      // Before any recording, the buffer has 0s — label should say "Minimum 30s required".
      expect(find.text('Minimum 30s required'), findsOneWidget);
    });

    testWidgets('connection warning is shown when no sensor is connected',
        (tester) async {
      await tester.pumpWidget(
          _wrapScreen(sensorService: _FakeSensorService()));
      await tester.pumpAndSettle();

      expect(find.text('Connect a wearable sensor to begin.'),
          findsOneWidget);
    });
  });
}
