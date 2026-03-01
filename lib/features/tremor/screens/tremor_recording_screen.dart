import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../models/sensor_data.dart';
import '../providers/tremor_providers.dart';
import '../widgets/medical_disclaimer_dialog.dart';
import '../widgets/recording_controls.dart';
import '../widgets/waveform_chart.dart';

/// Real-time tremor recording screen.
///
/// Shows the live accelerometer waveform, a timer, a minimum-time progress
/// bar, and Start / Stop buttons.
class TremorRecordingScreen extends ConsumerStatefulWidget {
  const TremorRecordingScreen({super.key});

  @override
  ConsumerState<TremorRecordingScreen> createState() =>
      _TremorRecordingScreenState();
}

class _TremorRecordingScreenState
    extends ConsumerState<TremorRecordingScreen> {
  Timer? _timer;
  StreamSubscription<dynamic>? _streamSub;
  final List<SensorData> _recorded = [];
  double _samplingRate = 50.0;

  @override
  void initState() {
    super.initState();
    _checkDisclaimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _checkDisclaimer() async {
    final ack = await ref.read(disclaimerAcknowledgedProvider.future);
    if (!ack && mounted) {
      await showMedicalDisclaimer(context);
      ref.invalidate(disclaimerAcknowledgedProvider);
    }
  }

  Future<void> _startRecording() async {
    _recorded.clear();
    ref.read(realtimeSensorDataProvider.notifier).clear();
    ref.read(recordingDurationProvider.notifier).state = 0;
    ref.read(recordingStateProvider.notifier).state = RecordingState.recording;
    ref.read(isSensorStreamingProvider.notifier).state = true;

    final sensorService = ref.read(wearableSensorServiceProvider);
    final stream = sensorService.startDataStream('simulated-device');

    _streamSub = stream.listen((result) {
      if (result case Success(:final data)) {
        _recorded.add(data);
        ref
            .read(realtimeSensorDataProvider.notifier)
            .addSample(data, _samplingRate);
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(recordingDurationProvider.notifier).state++;
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _timer = null;
    await _streamSub?.cancel();
    _streamSub = null;

    ref.read(recordingStateProvider.notifier).state = RecordingState.analyzing;
    ref.read(isSensorStreamingProvider.notifier).state = false;

    final sensorService = ref.read(wearableSensorServiceProvider);
    final rateResult = await sensorService.getSamplingRate();
    if (rateResult case Success(:final data)) {
      _samplingRate = data;
    }
    await sensorService.stopDataStream();

    final analysisService = ref.read(tremorAnalysisServiceProvider);
    final result =
        await analysisService.analyzeRecording(_recorded, _samplingRate);

    switch (result) {
      case Success(:final data):
        ref.read(currentTremorResultProvider.notifier).state = data;
        ref.read(recordingStateProvider.notifier).state =
            RecordingState.complete;
      case AppError(:final failure):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red,
            ),
          );
        }
        ref.read(recordingStateProvider.notifier).state = RecordingState.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingStateProvider);
    final elapsed = ref.watch(recordingDurationProvider);
    final samples = ref.watch(realtimeSensorDataProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waveform',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: WaveformChart(
              samples: samples,
              samplingRate: _samplingRate,
            ),
          ),
          const SizedBox(height: 24),
          RecordingControls(
            state: state,
            elapsedSeconds: elapsed,
            onStart: _startRecording,
            onStop: _stopRecording,
          ),
          const SizedBox(height: 16),
          _SensorStatus(
            isStreaming: ref.watch(isSensorStreamingProvider),
            samplingRate: _samplingRate,
          ),
        ],
      ),
    );
  }
}

class _SensorStatus extends StatelessWidget {
  const _SensorStatus({
    required this.isStreaming,
    required this.samplingRate,
  });

  final bool isStreaming;
  final double samplingRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.circle,
          size: 12,
          color: isStreaming ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          isStreaming
              ? 'Connected — ${samplingRate.toStringAsFixed(0)} Hz'
              : 'Not connected',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
