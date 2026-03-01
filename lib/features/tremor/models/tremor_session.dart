import 'sensor_data.dart';
import 'tremor_result.dart';

/// A complete tremor recording session, optionally with analysis results.
class TremorSession {
  const TremorSession({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    required this.durationSeconds,
    required this.samplingRate,
    this.updrsScore,
    this.dominantFrequency,
    this.tremorRatio,
    this.tremorPower,
    this.totalPower,
    this.rawData,
    this.result,
  });

  final String id;
  final String deviceId;
  final DateTime timestamp;
  final int durationSeconds;
  final double samplingRate;

  final int? updrsScore;
  final double? dominantFrequency;
  final double? tremorRatio;
  final double? tremorPower;
  final double? totalPower;

  /// Full raw sensor samples (optional; loaded on demand).
  final List<SensorData>? rawData;

  /// Completed analysis result, or `null` if not yet analysed.
  final TremorResult? result;

  /// Whether analysis has been completed for this session.
  bool get isAnalyzed => result != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'device_id': deviceId,
        'timestamp': timestamp.toIso8601String(),
        'duration_seconds': durationSeconds,
        'sampling_rate': samplingRate,
        'updrs_score': updrsScore,
        'dominant_frequency': dominantFrequency,
        'tremor_ratio': tremorRatio,
        'tremor_power': tremorPower,
        'total_power': totalPower,
      };

  factory TremorSession.fromMap(Map<String, dynamic> map) => TremorSession(
        id: map['id'] as String,
        deviceId: map['device_id'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
        samplingRate: (map['sampling_rate'] as num?)?.toDouble() ?? 0.0,
        updrsScore: (map['updrs_score'] as num?)?.toInt(),
        dominantFrequency: (map['dominant_frequency'] as num?)?.toDouble(),
        tremorRatio: (map['tremor_ratio'] as num?)?.toDouble(),
        tremorPower: (map['tremor_power'] as num?)?.toDouble(),
        totalPower: (map['total_power'] as num?)?.toDouble(),
      );
}
