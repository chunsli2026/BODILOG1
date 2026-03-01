import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/processing_result.dart';
import '../models/strip_layout.dart';
import '../services/color_extraction_service.dart';
import '../services/image_processing_service.dart';

/// Provides a singleton [ImageProcessingService].
final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService();
});

/// Provides a singleton [ColorExtractionService].
final colorExtractionServiceProvider = Provider<ColorExtractionService>((ref) {
  return ColorExtractionService();
});

/// Holds the currently selected [StripLayout]; `null` until the user selects
/// a strip type.
final stripLayoutProvider = StateProvider<StripLayout?>((ref) => null);

/// Holds the most recent [ProcessingResult]; `null` before first analysis.
final processingResultProvider = StateProvider<ProcessingResult?>((ref) => null);

/// Async provider that loads a [StripLayout] by name from the bundled JSON
/// assets (`assets/strip_configs/<layoutName>.json`).
///
/// Example usage:
/// ```dart
/// final layout = await ref.read(stripLayoutLoaderProvider('standard_10').future);
/// ```
final stripLayoutLoaderProvider =
    FutureProvider.family<StripLayout, String>((ref, layoutName) async {
  final jsonString =
      await rootBundle.loadString('assets/strip_configs/$layoutName.json');
  return StripLayout.fromJsonString(jsonString);
});
