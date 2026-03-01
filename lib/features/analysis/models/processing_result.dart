import 'package:image/image.dart' as img;

import 'pad_result.dart';

/// The complete output of the image processing pipeline for a single strip
/// image.
class ProcessingResult {
  /// File-system path of the original captured image.
  final String sourceImagePath;

  /// Timestamp at which processing completed.
  final DateTime processedAt;

  /// Name of the strip layout used (e.g. `"standard_10"`).
  final String stripLayoutName;

  /// Number of pads expected according to the strip layout.
  final int expectedPadCount;

  /// Number of pads successfully detected and extracted.
  final int detectedPadCount;

  /// Extraction results for each detected pad, ordered by [PadResult.padIndex].
  final List<PadResult> padResults;

  /// Pre-processed strip image retained only when debug mode is active.
  final img.Image? preprocessedImage;

  /// Wall-clock time taken by the full pipeline.
  final Duration processingDuration;

  const ProcessingResult({
    required this.sourceImagePath,
    required this.processedAt,
    required this.stripLayoutName,
    required this.expectedPadCount,
    required this.detectedPadCount,
    required this.padResults,
    required this.processingDuration,
    this.preprocessedImage,
  });

  /// `true` when every expected pad was successfully extracted.
  bool get isComplete => detectedPadCount == expectedPadCount;

  /// Mean confidence score across all extracted pads, or 0.0 if none.
  double get averageConfidence {
    if (padResults.isEmpty) return 0.0;
    final total =
        padResults.fold<double>(0.0, (sum, p) => sum + p.confidenceScore);
    return total / padResults.length;
  }

  /// Serialise to a JSON-compatible map (images are not serialised).
  Map<String, dynamic> toMap() {
    return {
      'sourceImagePath': sourceImagePath,
      'processedAt': processedAt.toIso8601String(),
      'stripLayoutName': stripLayoutName,
      'expectedPadCount': expectedPadCount,
      'detectedPadCount': detectedPadCount,
      'padResults': padResults.map((r) => r.toMap()).toList(),
      'processingDurationMs': processingDuration.inMilliseconds,
    };
  }

  /// Deserialise from a map produced by [toMap].
  factory ProcessingResult.fromMap(Map<String, dynamic> map) {
    final rawPads = map['padResults'] as List<dynamic>;
    return ProcessingResult(
      sourceImagePath: map['sourceImagePath'] as String,
      processedAt: DateTime.parse(map['processedAt'] as String),
      stripLayoutName: map['stripLayoutName'] as String,
      expectedPadCount: map['expectedPadCount'] as int,
      detectedPadCount: map['detectedPadCount'] as int,
      processingDuration: Duration(
        milliseconds: map['processingDurationMs'] as int,
      ),
      padResults: rawPads
          .map((r) => PadResult.fromMap(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
