import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/app/theme.dart';
import 'package:bodilog/features/camera/screens/image_review_screen.dart';
import 'package:bodilog/features/camera/widgets/camera_overlay_guide.dart';
import 'package:bodilog/features/camera/widgets/capture_button.dart';
import 'package:bodilog/features/camera/widgets/flash_toggle_button.dart';
import 'package:camera/camera.dart';

void main() {
  // ---------------------------------------------------------------------------
  // CaptureButton
  // ---------------------------------------------------------------------------
  group('CaptureButton', () {
    testWidgets('shows camera icon when not capturing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CaptureButton(onPressed: () {}),
          ),
        ),
      );
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows progress indicator when capturing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CaptureButton(onPressed: () {}, isCapturing: true),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsNothing);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptureButton(onPressed: () => tapped = true),
          ),
        ),
      );
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // FlashToggleButton
  // ---------------------------------------------------------------------------
  group('FlashToggleButton', () {
    testWidgets('shows flash_off icon for FlashMode.off', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashToggleButton(
              flashMode: FlashMode.off,
              onToggle: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
    });

    testWidgets('shows flash_auto icon for FlashMode.auto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashToggleButton(
              flashMode: FlashMode.auto,
              onToggle: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.flash_auto), findsOneWidget);
    });

    testWidgets('shows flash_on icon for FlashMode.always', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashToggleButton(
              flashMode: FlashMode.always,
              onToggle: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('calls onToggle when tapped', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashToggleButton(
              flashMode: FlashMode.auto,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      expect(toggled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // CameraOverlayGuide
  // ---------------------------------------------------------------------------
  group('CameraOverlayGuide', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: CameraOverlayGuide(),
            ),
          ),
        ),
      );
      expect(find.byType(CameraOverlayGuide), findsOneWidget);
    });

    testWidgets('shows alignment instruction text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: CameraOverlayGuide(),
            ),
          ),
        ),
      );
      expect(
        find.text('Align the test strip within the guide'),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ImageReviewScreen
  // ---------------------------------------------------------------------------
  group('ImageReviewScreen', () {
    testWidgets('displays Use Photo and Retake buttons', (tester) async {
      // Create a temporary file so Image.file doesn't throw.
      final tmpFile = File(
        '${Directory.systemTemp.path}/test_strip.png',
      );
      await tmpFile.writeAsBytes([0, 0, 0]); // minimal bytes

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            routes: {
              '/analysis': (_) => const Scaffold(body: Text('Analysis')),
            },
            home: ImageReviewScreen(imagePath: tmpFile.path),
          ),
        ),
      );

      expect(find.text('Use Photo'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);

      await tmpFile.delete();
    });

    testWidgets('Retake button pops the route', (tester) async {
      final tmpFile = File(
        '${Directory.systemTemp.path}/test_strip2.png',
      );
      await tmpFile.writeAsBytes([0, 0, 0]);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ImageReviewScreen(imagePath: tmpFile.path),
                    ),
                  ),
                  child: const Text('Open Review'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Review'));
      await tester.pumpAndSettle();

      expect(find.text('Retake'), findsOneWidget);
      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();

      // After retake, we should be back on the previous page.
      expect(find.text('Open Review'), findsOneWidget);

      await tmpFile.delete();
    });
  });
}
