import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/error/result.dart';
import '../models/sensor_data.dart';
import '../models/tremor_result.dart';
import '../providers/tremor_providers.dart';
import '../widgets/medical_disclaimer_dialog.dart';
import '../widgets/waveform_chart.dart';

/// Screen for recording a tremor session in real time.
///
/// Shows a live accelerometer waveform, a timer, a minimum-time progress
/// indicator, and start/stop/analyze controls.
class TremorRecordingScreen extends ConsumerStatefulWidget {
  const TremorRecordingScreen({super.key});

  @override
  ConsumerState<TremorRecordingScreen> createState() =>
      _TremorRecordingScreenState();
}

class _TremorRecordingScreenState
    extends ConsumerState<TremorRecordingScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _recordingStopped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MedicalDisclaimerDialog.showIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    final sensorService = ref.read(wearableSensorServiceProvider);
    if (!sensorService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Connect a wearable sensor to begin recording.')),
      );
      return;
    }

    ref.read(isRecordingProvider.notifier).state = true;
    ref.read(sensorBufferProvider.notifier).reset(50.0);
    setState(() {
      _elapsedSeconds = 0;
      _recordingStopped = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    final stream = sensorService.startDataStream();
    stream.listen((result) {
      if (!mounted) return;
      if (result.isSuccess) {
        ref
            .read(sensorBufferProvider.notifier)
            .addPoint((result as Success<SensorDataPoint>).data);
      }
    });
  }

  void _stopRecording() {
    ref.read(isRecordingProvider.notifier).state = false;
    _timer?.cancel();
    _timer = null;
    ref.read(wearableSensorServiceProvider).stopDataStream();
    setState(() => _recordingStopped = true);
  }

  Future<void> _analyzeRecording() async {
    final buffer = ref.read(sensorBufferProvider);
    final service = ref.read(tremorAnalysisServiceProvider);
    final result = await service.analyzeBuffer(buffer);
    if (!mounted) return;
    if (result.isSuccess) {
      ref.read(currentTremorResultProvider.notifier).state =
          (result as Success<TremorResult>).data;
      Navigator.pushNamed(context, '/tremor/results');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                (result as AppError<TremorResult>).failure.message)),
      );
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(isRecordingProvider);
    final buffer = ref.watch(sensorBufferProvider);
    final sensorConnected =
        ref.read(wearableSensorServiceProvider).isConnected;

    final double progress =
        (buffer.durationSeconds / 30.0).clamp(0.0, 1.0);
    final Color progressColor = buffer.durationSeconds < 30
        ? AppTheme.error
        : buffer.durationSeconds < 60
            ? AppTheme.warning
            : AppTheme.success;

    return Scaffold(
      appBar: AppBar(title: const Text('Tremor Recording')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status banner.
            if (!sensorConnected)
              Card(
                color: AppTheme.warning.withOpacity(0.15),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_disabled,
                          color: AppTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connect a wearable sensor to begin.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/devices'),
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Waveform.
            SizedBox(
              height: 160,
              child: WaveformChart(
                data: buffer.accelMagnitudes,
                samplingRateHz: buffer.samplingRateHz,
              ),
            ),

            const SizedBox(height: 16),

            // Timer.
            Center(
              child: Text(
                _formatTime(_elapsedSeconds),
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontFamily: 'monospace'),
              ),
            ),

            const SizedBox(height: 8),

            // Sampling rate.
            Center(
              child: Text(
                'Sampling rate: ${buffer.samplingRateHz.toStringAsFixed(0)} Hz',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

            const SizedBox(height: 16),

            // Minimum time progress bar.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buffer.durationSeconds < 30
                      ? 'Minimum 30s required'
                      : buffer.durationSeconds < 60
                          ? 'Recommended: 60s'
                          : '✓ Recommended duration reached',
                  style: TextStyle(
                      color: progressColor, fontSize: 12),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    color: progressColor,
                    backgroundColor: Colors.grey.shade200,
                    minHeight: 8,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Controls.
            if (!_recordingStopped)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isRecording ? AppTheme.error : AppTheme.success,
                ),
                onPressed: isRecording
                    ? (buffer.hasMinimumData ? _stopRecording : null)
                    : _startRecording,
                child: Text(
                    isRecording ? 'Stop Recording' : 'Start Recording'),
              ),

            if (_recordingStopped) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _analyzeRecording,
                child: const Text('Analyze'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                  _recordingStopped = false;
                  _elapsedSeconds = 0;
                }),
                child: const Text('Record Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
