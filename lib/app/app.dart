import 'package:flutter/material.dart';

import '../features/camera/screens/camera_capture_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import 'router.dart';
import 'theme.dart';

/// Root application widget wrapping [MaterialApp] with theme and routing.
class BodiLogApp extends StatelessWidget {
  const BodiLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BodiLog',
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.dashboard,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const _HomeShell(),
    );
  }
}

/// Main shell with [BottomNavigationBar] managing the top-level tabs.
class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    CameraCaptureScreen(),
    _PlaceholderScreen(label: 'Devices'),
    _PlaceholderScreen(label: 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'Devices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

/// Generic placeholder screen used for tabs not yet implemented.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Text(
          '$label — Coming Soon',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
