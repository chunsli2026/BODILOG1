import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../shared/database/tremor_repository.dart';
import '../models/sensor_data.dart';
import '../models/tremor_result.dart';
import '../models/tremor_session.dart';
import '../services/tremor_analysis_service.dart';
import '../services/wearable_sensor_service.dart';

// ── Services ─────────────────────────────────────────────────────────────────

/// Provides the [TremorAnalysisService] singleton.
final tremorAnalysisServiceProvider = Provider<TremorAnalysisService>((ref) {
  return TremorAnalysisService();
});

/// Provides the [WearableSensorService] singleton.
final wearableSensorServiceProvider = Provider<WearableSensorService>((ref) {
  final service = WearableSensorService();
  ref.onDispose(service.stopDataStream);
  return service;
});

/// Provides the [TremorRepository] singleton.
final tremorRepositoryProvider = Provider<TremorRepository>((ref) {
  return TremorRepository();
});

// ── Streaming state ───────────────────────────────────────────────────────────

/// Whether the wearable sensor is currently streaming data.
final isSensorStreamingProvider = StateProvider<bool>((ref) => false);

// ── Recording state ───────────────────────────────────────────────────────────

/// Lifecycle of a tremor recording.
enum RecordingState { idle, recording, analyzing, complete, error }

/// Current recording lifecycle state.
final recordingStateProvider =
    StateProvider<RecordingState>((ref) => RecordingState.idle);

/// Elapsed recording time in whole seconds.
final recordingDurationProvider = StateProvider<int>((ref) => 0);

// ── Real-time waveform ────────────────────────────────────────────────────────

/// Notifier that keeps the last 5 seconds of sensor data for the waveform.
class RealtimeSensorNotifier extends StateNotifier<List<SensorData>> {
  RealtimeSensorNotifier() : super([]);

  /// Append [sample] and discard data older than 5 seconds.
  void addSample(SensorData sample, double samplingRate) {
    final maxSamples = (samplingRate * 5).ceil();
    final next = [...state, sample];
    state = next.length > maxSamples
        ? next.sublist(next.length - maxSamples)
        : next;
  }

  /// Clear all buffered samples.
  void clear() => state = [];
}

/// Real-time sensor data buffer for waveform display (last 5 seconds).
final realtimeSensorDataProvider =
    StateNotifierProvider<RealtimeSensorNotifier, List<SensorData>>(
  (ref) => RealtimeSensorNotifier(),
);

// ── Analysis result ───────────────────────────────────────────────────────────

/// The most recent tremor analysis result, or `null` if none yet.
final currentTremorResultProvider = StateProvider<TremorResult?>((ref) => null);

// ── Persisted sessions ────────────────────────────────────────────────────────

/// Loads all tremor sessions from the database.
final tremorSessionsProvider = FutureProvider<List<TremorSession>>((ref) async {
  final repo = ref.read(tremorRepositoryProvider);
  final result = await repo.getTremorSessions();
  return switch (result) {
    Success(:final data) => data,
    AppError() => <TremorSession>[],
  };
});

// ── Disclaimer ────────────────────────────────────────────────────────────────

const _disclaimerKey = 'tremor_disclaimer_acknowledged';

/// Whether the medical disclaimer has been acknowledged.
final disclaimerAcknowledgedProvider = FutureProvider<bool>((ref) async {
  const storage = FlutterSecureStorage();
  final value = await storage.read(key: _disclaimerKey);
  return value == 'true';
});

/// Persist disclaimer acknowledgment.
Future<void> acknowledgeDisclaimer() async {
  const storage = FlutterSecureStorage();
  await storage.write(key: _disclaimerKey, value: 'true');
}
