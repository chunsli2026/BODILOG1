import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/sensor_data.dart';
import '../models/tremor_result.dart';
import '../models/tremor_session.dart';
import '../services/tremor_analysis_service.dart';
import '../services/wearable_sensor_service.dart';
import '../../../core/error/result.dart';

// ---------------------------------------------------------------------------
// Service providers
// ---------------------------------------------------------------------------

/// Provides the singleton [WearableSensorService].
final wearableSensorServiceProvider =
    Provider<WearableSensorService>((ref) {
  return WearableSensorService();
});

/// Provides the singleton [TremorAnalysisService].
final tremorAnalysisServiceProvider =
    Provider<TremorAnalysisService>((ref) {
  return TremorAnalysisService();
});

// ---------------------------------------------------------------------------
// Sensor data stream
// ---------------------------------------------------------------------------

/// Live stream of sensor data points from the connected wearable.
final sensorDataStreamProvider =
    StreamProvider<SensorDataPoint>((ref) {
  final service = ref.read(wearableSensorServiceProvider);
  return service.startDataStream().map((result) {
    if (result is Success<SensorDataPoint>) return result.data;
    throw Exception('Sensor data error');
  });
});

// ---------------------------------------------------------------------------
// Recording buffer
// ---------------------------------------------------------------------------

/// Notifier that maintains the live [SensorDataBuffer].
class SensorBufferNotifier extends StateNotifier<SensorDataBuffer> {
  SensorBufferNotifier()
      : super(SensorDataBuffer(
          samplingRateHz: 50.0,
          recordingStart: DateTime.now(),
        ));

  /// Adds a data point to the buffer.
  void addPoint(SensorDataPoint point) {
    state.addDataPoint(point);
    // Trigger rebuild by reassigning state.
    state = state;
  }

  /// Resets the buffer for a new recording session.
  void reset(double samplingRateHz) {
    state = SensorDataBuffer(
      samplingRateHz: samplingRateHz,
      recordingStart: DateTime.now(),
    );
  }
}

/// Provides the live [SensorDataBuffer] and exposes [SensorBufferNotifier].
final sensorBufferProvider =
    StateNotifierProvider<SensorBufferNotifier, SensorDataBuffer>(
        (ref) => SensorBufferNotifier());

// ---------------------------------------------------------------------------
// Recording state
// ---------------------------------------------------------------------------

/// Whether a recording session is currently in progress.
final isRecordingProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// Analysis result
// ---------------------------------------------------------------------------

/// The most recently computed [TremorResult], or `null` before analysis.
final currentTremorResultProvider =
    StateProvider<TremorResult?>((ref) => null);

// ---------------------------------------------------------------------------
// Session history
// ---------------------------------------------------------------------------

/// Async provider that loads past [TremorSession]s from SQLite.
final tremorSessionsProvider =
    FutureProvider<List<TremorSession>>((ref) async {
  final service = ref.read(tremorAnalysisServiceProvider);
  final result = await service.getSessions();
  return result is Success<List<TremorSession>> ? result.data : [];
});

// ---------------------------------------------------------------------------
// Medical disclaimer
// ---------------------------------------------------------------------------

const String _kDisclaimerKey = 'tremor_disclaimer_acknowledged';

/// Returns `true` when the user has previously acknowledged the disclaimer.
final disclaimerAcknowledgedProvider = FutureProvider<bool>((ref) async {
  const storage = FlutterSecureStorage();
  final value = await storage.read(key: _kDisclaimerKey);
  return value == 'true';
});

/// Writes the disclaimer acknowledgment to secure storage.
Future<void> acknowledgeDisclaimer() async {
  const storage = FlutterSecureStorage();
  await storage.write(key: _kDisclaimerKey, value: 'true');
}
