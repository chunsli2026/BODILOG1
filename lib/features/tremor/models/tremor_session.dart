import 'dart:convert';

import 'sensor_data.dart';
import 'tremor_result.dart';

/// A complete tremor recording session with metadata and analysis result.
class TremorSession {
  const TremorSession({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    required this.durationSeconds,
    required this.samplingRateHz,
    required this.result,
    this.rawData,
  });

  /// Unique session identifier (UUID string).
  final String id;

  /// BLE device identifier of the wearable sensor.
  final String deviceId;

  /// When the recording session was started (UTC).
  final DateTime timestamp;

  /// Recording duration in seconds.
  final int durationSeconds;

  /// Sensor sampling rate in Hz.
  final double samplingRateHz;

  /// Analysis result for this session.
  final TremorResult result;

  /// Optional raw sensor data points (loaded on demand).
  final List<SensorDataPoint>? rawData;

  /// Converts this session to a [Map] for SQLite insertion.
  ///
  /// The returned map matches the `tremor_sessions` table schema and also
  /// includes extra fields required to reconstruct [TremorResult].
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'duration_seconds': durationSeconds,
      'sample_rate_hz': samplingRateHz,
      'updrs_score': result.updrsScore,
      'updrs_label': result.updrsLabel,
      'dominant_frequency_hz': result.dominantFrequencyHz,
      'tremor_ratio': result.tremorRatio,
      'tremor_power': result.tremorPower,
      'total_power': result.totalPower,
      'fft_frequencies': jsonEncode(result.fftResult.frequencies),
      'fft_amplitudes': jsonEncode(result.fftResult.amplitudes),
      'recording_duration_ms': result.recordingDuration.inMilliseconds,
    };
  }

  /// Creates a [TremorSession] from a SQLite row [map].
  factory TremorSession.fromMap(Map<String, dynamic> map) {
    final freqsJson = map['fft_frequencies'] as String?;
    final ampsJson = map['fft_amplitudes'] as String?;
    final freqs = freqsJson != null
        ? (jsonDecode(freqsJson) as List)
            .map((e) => (e as num).toDouble())
            .toList()
        : <double>[];
    final amps = ampsJson != null
        ? (jsonDecode(ampsJson) as List)
            .map((e) => (e as num).toDouble())
            .toList()
        : <double>[];

    final durationSeconds = map['duration_seconds'] as int;
    final recordingDurationMs = map['recording_duration_ms'] as int? ??
        durationSeconds * 1000;
    final updrsScore = map['updrs_score'] as int;

    final result = TremorResult(
      updrsScore: updrsScore,
      updrsLabel: map['updrs_label'] as String? ??
          _labelForScore(updrsScore),
      dominantFrequencyHz:
          (map['dominant_frequency_hz'] as num).toDouble(),
      tremorRatio: (map['tremor_ratio'] as num).toDouble(),
      tremorPower: (map['tremor_power'] as num).toDouble(),
      totalPower: (map['total_power'] as num).toDouble(),
      fftResult: FftResult(frequencies: freqs, amplitudes: amps),
      recordingDuration: Duration(milliseconds: recordingDurationMs),
      samplingRateHz: (map['sample_rate_hz'] as num).toDouble(),
    );

    return TremorSession(
      id: map['id'] as String,
      deviceId: map['device_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      durationSeconds: durationSeconds,
      samplingRateHz: (map['sample_rate_hz'] as num).toDouble(),
      result: result,
    );
  }

  static String _labelForScore(int score) {
    const labels = ['No tremor', 'Slight', 'Mild', 'Moderate', 'Severe'];
    return (score >= 0 && score < labels.length)
        ? labels[score]
        : 'Unknown';
  }
}
