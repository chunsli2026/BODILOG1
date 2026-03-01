import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tremor_history_screen.dart';
import 'tremor_recording_screen.dart';
import 'tremor_results_screen.dart';

/// Main tremor analysis screen with three tabs: Record, Results, History.
class TremorScreen extends ConsumerStatefulWidget {
  const TremorScreen({super.key});

  @override
  ConsumerState<TremorScreen> createState() => _TremorScreenState();
}

class _TremorScreenState extends ConsumerState<TremorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tremor Analysis'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fiber_manual_record), text: 'Record'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Results'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TremorRecordingScreen(),
          TremorResultsScreen(),
          TremorHistoryScreen(),
        ],
      ),
    );
  }
}
