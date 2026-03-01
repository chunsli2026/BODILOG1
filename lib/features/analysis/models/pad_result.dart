import 'package:image/image.dart' as img;

import '../services/color_extraction_service.dart';

/// The colour extracted from a single reactive pad, together with metadata.
class PadResult {
  /// Zero-based pad index matching [PadConfig.index].
  final int padIndex;

  /// Human-readable parameter name (e.g. `"Glucose"`, `"pH"`).
  final String parameterName;

  /// Median CIE LAB values sampled from the central 60 % of the pad.
  final LabColor labValues;

  /// Confidence score (0.0–1.0) based on colour uniformity within the pad.
  ///
  /// A value close to 1.0 indicates a uniform, reliable reading; a value
  /// close to 0.0 indicates high variance and a potentially unreliable
  /// reading.
  final double confidenceScore;

  /// Optional cropped pad image, retained only when debug mode is active.
  final img.Image? padImage;

  const PadResult({
    required this.padIndex,
    required this.parameterName,
    required this.labValues,
    required this.confidenceScore,
    this.padImage,
  });

  /// Serialise to a JSON-compatible map (image is not serialised).
  Map<String, dynamic> toMap() {
    return {
      'padIndex': padIndex,
      'parameterName': parameterName,
      'labValues': labValues.toMap(),
      'confidenceScore': confidenceScore,
    };
  }

  /// Deserialise from a map produced by [toMap].
  factory PadResult.fromMap(Map<String, dynamic> map) {
    return PadResult(
      padIndex: map['padIndex'] as int,
      parameterName: map['parameterName'] as String,
      labValues: LabColor.fromMap(
        Map<String, dynamic>.from(map['labValues'] as Map),
      ),
      confidenceScore: (map['confidenceScore'] as num).toDouble(),
    );
  }
}
