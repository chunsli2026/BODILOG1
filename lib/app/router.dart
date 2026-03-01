import 'package:flutter/material.dart';

import '../features/camera/screens/camera_capture_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';

/// Named route constants and route generation for the app.
class AppRouter {
  AppRouter._();

  static const String dashboard = '/dashboard';
  static const String camera = '/camera';
  static const String imageReview = '/camera/review';
  static const String analysis = '/analysis';
  static const String devices = '/devices';
  static const String history = '/history';
  static const String results = '/results';
  static const String tremor = '/tremor';

  /// Generates routes for the [MaterialApp.onGenerateRoute] callback.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
          settings: settings,
        );
      case camera:
        return MaterialPageRoute(
          builder: (_) => const CameraCaptureScreen(),
          settings: settings,
        );
      case analysis:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'Analysis'),
          settings: settings,
        );
      case devices:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'Devices'),
          settings: settings,
        );
      case history:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'History'),
          settings: settings,
        );
      case results:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'Results'),
          settings: settings,
        );
      case tremor:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'Tremor'),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'Not Found'),
          settings: settings,
        );
    }
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — Coming Soon')),
    );
  }
}
