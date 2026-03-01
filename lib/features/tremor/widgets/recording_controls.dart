import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../providers/tremor_providers.dart';

/// Start / Stop recording button pair with timer and minimum-time progress bar.
class RecordingControls extends StatelessWidget {
  const RecordingControls({
    super.key,
    required this.state,
    required this.elapsedSeconds,
    required this.onStart,
    required this.onStop,
  });

  final RecordingState state;
  final int elapsedSeconds;
  final VoidCallback onStart;
  final VoidCallback onStop;

  static const int _minimumSeconds = 30;
  static const int _recommendedSeconds = 60;

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = state == RecordingState.recording;
    final canStop = isRecording && elapsedSeconds >= _minimumSeconds;
    final progress =
        (elapsedSeconds / _minimumSeconds).clamp(0.0, 1.0);
    final barColor =
        elapsedSeconds >= _minimumSeconds ? Colors.green : Colors.orange;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Timer.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRecording)
              const _PulsingDot(),
            const SizedBox(width: 8),
            Text(
              _formatTime(elapsedSeconds),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: progress,
              color: barColor,
              backgroundColor: Colors.grey.shade300,
              minHeight: 8,
            ),
            const SizedBox(height: 4),
            Text(
              'Minimum: ${_minimumSeconds}s  |  Recommended: ${_recommendedSeconds}s',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Buttons.
        if (!isRecording)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: state == RecordingState.idle ? onStart : null,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Start Recording', style: TextStyle(fontSize: 16)),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: canStop ? onStop : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Recording', style: TextStyle(fontSize: 16)),
            ),
          ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Opacity(
        opacity: _animation.value,
        child: const Icon(Icons.circle, color: Colors.red, size: 16),
      ),
    );
  }
}
