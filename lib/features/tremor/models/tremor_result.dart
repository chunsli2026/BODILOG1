import 'dart:convert';

import 'package:flutter/material.dart';

/// A single frequency–amplitude pair from a spectrum.
class FrequencyAmplitude {
  const FrequencyAmplitude({
    required this.frequency,
    required this.amplitude,
  });

  /// Frequency in Hz.
  final double frequency;

  /// Amplitude at [frequency].
  final double amplitude;
}

/// Container for a discrete Fourier transform result.
class FftResult {
  const FftResult({
    required this.frequencies,
    required this.amplitudes,
    this.frequencyResolution = 0.0,
  });

  /// Frequency bins in Hz (same length as [amplitudes]).
  final List<double> frequencies;

  /// Amplitude at each frequency bin.
  final List<double> amplitudes;

  /// Spacing between adjacent frequency bins (Hz).
  final double frequencyResolution;

  /// Returns the amplitude at [frequency] by finding the nearest bin.
  double getAmplitudeAt(double frequency) {
    if (frequencies.isEmpty) return 0.0;
    var nearest = 0;
    var minDiff = (frequencies[0] - frequency).abs();
    for (var i = 1; i < frequencies.length; i++) {
      final diff = (frequencies[i] - frequency).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = i;
      }
    }
    return amplitudes[nearest];
  }

  /// Returns all frequency–amplitude pairs within [[minFreq], [maxFreq]].
  List<FrequencyAmplitude> getRange(double minFreq, double maxFreq) {
    final result = <FrequencyAmplitude>[];
    for (var i = 0; i < frequencies.length; i++) {
      if (frequencies[i] >= minFreq && frequencies[i] <= maxFreq) {
        result.add(FrequencyAmplitude(
          frequency: frequencies[i],
          amplitude: amplitudes[i],
        ));
      }
    }
    return result;
  }
}

/// Analysis result produced by [TremorAnalysisService.analyzeBuffer].
class TremorResult {
  const TremorResult({
    required this.updrsScore,
    required this.updrsLabel,
    required this.dominantFrequencyHz,
    required this.tremorRatio,
    required this.tremorPower,
    required this.totalPower,
    required this.fftResult,
    required this.recordingDuration,
    required this.samplingRateHz,
  });

  /// UPDRS tremor score (0–4).
  final int updrsScore;

  /// Human-readable UPDRS severity label.
  final String updrsLabel;

  /// Dominant tremor peak frequency within 3–7 Hz (Hz).
  final double dominantFrequencyHz;

  /// Ratio of tremor power (3–7 Hz) to total power (1–12 Hz).
  final double tremorRatio;

  /// Area under the spectral curve in the 3–7 Hz tremor band.
  final double tremorPower;

  /// Area under the spectral curve in the 1–12 Hz band.
  final double totalPower;

  /// Full FFT result used for spectrum visualisation.
  final FftResult fftResult;

  /// Duration of the recording that produced this result.
  final Duration recordingDuration;

  /// Sampling rate of the sensor (Hz).
  final double samplingRateHz;

  /// Display colour associated with this UPDRS score.
  Color get scoreColor {
    switch (updrsScore) {
      case 0:
        return const Color(0xFF27AE60); // green
      case 1:
        return const Color(0xFF2ECC71); // light green
      case 2:
        return const Color(0xFFF39C12); // amber
      case 3:
        return const Color(0xFFE67E22); // orange
      case 4:
        return const Color(0xFFE74C3C); // red
      default:
        return const Color(0xFF95A5A6); // grey
    }
  }

  /// Returns `true` when the UPDRS score indicates significant tremor (≥ 2).
  bool get isSignificant => updrsScore >= 2;

  /// Converts this result to a [Map] for storage.
  Map<String, dynamic> toMap() {
    return {
      'updrs_score': updrsScore,
      'updrs_label': updrsLabel,
      'dominant_frequency_hz': dominantFrequencyHz,
      'tremor_ratio': tremorRatio,
      'tremor_power': tremorPower,
      'total_power': totalPower,
      'fft_frequencies': jsonEncode(fftResult.frequencies),
      'fft_amplitudes': jsonEncode(fftResult.amplitudes),
      'recording_duration_ms': recordingDuration.inMilliseconds,
      'sampling_rate_hz': samplingRateHz,
    };
  }

  /// Creates a [TremorResult] from a storage [map].
  factory TremorResult.fromMap(Map<String, dynamic> map) {
    final freqs =
        (jsonDecode(map['fft_frequencies'] as String) as List)
            .map((e) => (e as num).toDouble())
            .toList();
    final amps =
        (jsonDecode(map['fft_amplitudes'] as String) as List)
            .map((e) => (e as num).toDouble())
            .toList();
    return TremorResult(
      updrsScore: map['updrs_score'] as int,
      updrsLabel: map['updrs_label'] as String,
      dominantFrequencyHz:
          (map['dominant_frequency_hz'] as num).toDouble(),
      tremorRatio: (map['tremor_ratio'] as num).toDouble(),
      tremorPower: (map['tremor_power'] as num).toDouble(),
      totalPower: (map['total_power'] as num).toDouble(),
      fftResult: FftResult(frequencies: freqs, amplitudes: amps),
      recordingDuration:
          Duration(milliseconds: map['recording_duration_ms'] as int),
      samplingRateHz: (map['sampling_rate_hz'] as num).toDouble(),
    );
  }
}
