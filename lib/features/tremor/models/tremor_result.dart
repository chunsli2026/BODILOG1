import 'package:flutter/material.dart';

/// The outcome of a tremor analysis pipeline run.
class TremorResult {
  const TremorResult({
    required this.updrsScore,
    required this.updrsLabel,
    required this.dominantFrequency,
    required this.tremorRatio,
    required this.tremorPower,
    required this.totalPower,
    required this.fftFrequencies,
    required this.fftAmplitudes,
    required this.samplingRate,
    required this.durationSeconds,
    required this.analyzedAt,
  });

  /// UPDRS tremor score 0–4.
  final int updrsScore;

  /// Human-readable label for [updrsScore].
  final String updrsLabel;

  /// Dominant tremor frequency in Hz (within 3–7 Hz band).
  final double dominantFrequency;

  /// Ratio of tremor-band power to total signal power (0–1).
  final double tremorRatio;

  /// Signal power in the 3–7 Hz tremor band.
  final double tremorPower;

  /// Total signal power in the 1–12 Hz band.
  final double totalPower;

  /// Frequency axis values for the FFT spectrum chart.
  final List<double> fftFrequencies;

  /// Amplitude values for the FFT spectrum chart.
  final List<double> fftAmplitudes;

  /// Sensor sampling rate used during recording.
  final double samplingRate;

  /// Recording length in seconds.
  final int durationSeconds;

  /// Wall-clock time when analysis completed.
  final DateTime analyzedAt;

  /// Returns the severity colour matching [updrsScore].
  Color get severityColor {
    switch (updrsScore) {
      case 0:
        return const Color(0xFF27AE60); // green
      case 1:
        return const Color(0xFFF1C40F); // yellow
      case 2:
        return const Color(0xFFE67E22); // orange
      case 3:
        return const Color(0xFFE74C3C); // red
      default:
        return const Color(0xFF922B21); // dark red
    }
  }

  Map<String, dynamic> toMap() => {
        'updrs_score': updrsScore,
        'updrs_label': updrsLabel,
        'dominant_frequency': dominantFrequency,
        'tremor_ratio': tremorRatio,
        'tremor_power': tremorPower,
        'total_power': totalPower,
        'fft_frequencies': fftFrequencies,
        'fft_amplitudes': fftAmplitudes,
        'sampling_rate': samplingRate,
        'duration_seconds': durationSeconds,
        'analyzed_at': analyzedAt.toIso8601String(),
      };

  factory TremorResult.fromMap(Map<String, dynamic> map) => TremorResult(
        updrsScore: (map['updrs_score'] as num).toInt(),
        updrsLabel: map['updrs_label'] as String,
        dominantFrequency: (map['dominant_frequency'] as num).toDouble(),
        tremorRatio: (map['tremor_ratio'] as num).toDouble(),
        tremorPower: (map['tremor_power'] as num).toDouble(),
        totalPower: (map['total_power'] as num).toDouble(),
        fftFrequencies: (map['fft_frequencies'] as List)
            .map((e) => (e as num).toDouble())
            .toList(),
        fftAmplitudes: (map['fft_amplitudes'] as List)
            .map((e) => (e as num).toDouble())
            .toList(),
        samplingRate: (map['sampling_rate'] as num).toDouble(),
        durationSeconds: (map['duration_seconds'] as num).toInt(),
        analyzedAt: DateTime.parse(map['analyzed_at'] as String),
      );
}
