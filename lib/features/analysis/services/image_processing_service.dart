import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../models/pad_result.dart';
import '../models/processing_result.dart';
import '../models/strip_layout.dart';
import 'color_extraction_service.dart';
import 'strip_detector_service.dart';

/// Orchestrates the full image-processing pipeline for a urinalysis test strip.
///
/// Pipeline steps
/// 1. Load the PNG from disk.
/// 2. Detect and auto-crop the strip region.
/// 3. Apply perspective correction.
/// 4. Normalise white balance.
/// 5. Apply gentle Gaussian noise reduction.
/// 6. Segment each pad and extract CIE LAB colour values.
class ImageProcessingService {
  /// Default strip layout used when none is supplied to [processStripImage].
  ///
  /// This is a hard-coded fallback that mirrors `assets/strip_configs/standard_10.json`.
  /// It exists so that the service can be used synchronously (e.g. in unit tests)
  /// without requiring `rootBundle`.  If the JSON file changes, update this too.
  static final StripLayout _defaultLayout = StripLayout(
    name: 'standard_10',
    padCount: 10,
    padSpacing: 0.08,
    padAspectRatio: 2.5,
    pads: [
      const PadConfig(index: 0, parameterName: 'Leukocytes', relativePosition: 0.05, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 1, parameterName: 'Nitrite', relativePosition: 0.14, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 2, parameterName: 'Urobilinogen', relativePosition: 0.23, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 3, parameterName: 'Protein', relativePosition: 0.32, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 4, parameterName: 'pH', relativePosition: 0.41, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 5, parameterName: 'Blood', relativePosition: 0.50, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 6, parameterName: 'Specific Gravity', relativePosition: 0.59, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 7, parameterName: 'Ketone', relativePosition: 0.68, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 8, parameterName: 'Bilirubin', relativePosition: 0.77, relativeWidth: 0.6, relativeHeight: 0.07),
      const PadConfig(index: 9, parameterName: 'Glucose', relativePosition: 0.86, relativeWidth: 0.6, relativeHeight: 0.07),
    ],
  );

  final ColorExtractionService _colorExtractor;
  final StripDetectorService _stripDetector;

  /// When `true`, each pipeline step is logged with timing information.
  bool debugMode = false;

  ImageProcessingService({
    ColorExtractionService? colorExtractor,
    StripDetectorService? stripDetector,
  })  : _colorExtractor = colorExtractor ?? ColorExtractionService(),
        _stripDetector = stripDetector ?? StripDetectorService();

  // ── Public API ─────────────────────────────────────────────────────────

  /// Process the strip image at [imagePath] and return a [ProcessingResult].
  ///
  /// [layout] defaults to a built-in standard 10-pad layout when not supplied.
  Future<Result<ProcessingResult>> processStripImage(
    String imagePath, {
    StripLayout? layout,
  }) async {
    final start = DateTime.now();
    final effectiveLayout = layout ?? _defaultLayout;

    // Step 0: load image from disk.
    final loadResult = await _loadImage(imagePath);
    if (loadResult.isError) return AppError((loadResult as AppError).failure);
    var image = (loadResult as Success<img.Image>).data;
    _log('Loaded image: ${image.width}×${image.height}');

    // Step 1: validate image quality.
    final qualityResult = _checkImageQuality(image);
    if (qualityResult.isError) return AppError((qualityResult as AppError).failure);

    // Step 2: detect and crop the strip.
    final cropResult = await detectAndCropStrip(image);
    if (cropResult.isError) return AppError((cropResult as AppError).failure);
    image = (cropResult as Success<img.Image>).data;
    _log('After crop: ${image.width}×${image.height}');

    // Step 3: perspective correction (uses bounding-box corners).
    final corners = [
      StripPoint(0, 0),
      StripPoint(image.width - 1, 0),
      StripPoint(image.width - 1, image.height - 1),
      StripPoint(0, image.height - 1),
    ];
    final perspResult = await correctPerspective(image, corners);
    if (perspResult.isError) return AppError((perspResult as AppError).failure);
    image = (perspResult as Success<img.Image>).data;
    _log('After perspective correction: ${image.width}×${image.height}');

    // Step 4: white balance normalisation.
    final wbResult = await normalizeWhiteBalance(image);
    if (wbResult.isError) return AppError((wbResult as AppError).failure);
    image = (wbResult as Success<img.Image>).data;
    _log('White balance applied');

    // Step 5: noise reduction.
    image = reduceNoise(image);
    _log('Noise reduction applied');

    // Step 6: segment pads and extract colours.
    final padResults = _segmentAndExtract(image, effectiveLayout);
    if (padResults.isEmpty && effectiveLayout.padCount > 0) {
      return AppError(
        AnalysisFailure(
          'No pads were detected. '
          'Please ensure the entire strip is visible in the photo.',
        ),
      );
    }

    if (padResults.length < effectiveLayout.padCount) {
      _log('Warning: only ${padResults.length}/${effectiveLayout.padCount} pads extracted');
    }

    final duration = DateTime.now().difference(start);
    _log('Processing complete in ${duration.inMilliseconds} ms');

    return Success(
      ProcessingResult(
        sourceImagePath: imagePath,
        processedAt: DateTime.now(),
        stripLayoutName: effectiveLayout.name,
        expectedPadCount: effectiveLayout.padCount,
        detectedPadCount: padResults.length,
        padResults: padResults,
        processingDuration: duration,
        preprocessedImage: debugMode ? image : null,
      ),
    );
  }

  /// Detect the strip in [sourceImage] and return the cropped region.
  Future<Result<img.Image>> detectAndCropStrip(img.Image sourceImage) async {
    return _stripDetector.detectAndCrop(sourceImage);
  }

  /// Apply perspective correction to [croppedImage] using the supplied
  /// [corners] (top-left, top-right, bottom-right, bottom-left).
  Future<Result<img.Image>> correctPerspective(
    img.Image croppedImage,
    List<StripPoint> corners,
  ) async {
    return _stripDetector.correctPerspective(croppedImage, corners);
  }

  /// Normalise the white balance of [image] using the brightest non-pad
  /// region as a reference.
  Future<Result<img.Image>> normalizeWhiteBalance(img.Image image) async {
    // Find the brightest region (assumed to be the white strip body).
    int sumR = 0, sumG = 0, sumB = 0, count = 0;
    const sampleStep = 4; // sample every 4th pixel for speed

    for (var y = 0; y < image.height; y += sampleStep) {
      for (var x = 0; x < image.width; x += sampleStep) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        final luma = (0.299 * r + 0.587 * g + 0.114 * b).round();
        if (luma > 200) {
          sumR += r;
          sumG += g;
          sumB += b;
          count++;
        }
      }
    }

    if (count == 0) return Success(image);

    final avgR = sumR / count;
    final avgG = sumG / count;
    final avgB = sumB / count;
    final maxAvg = [avgR, avgG, avgB].reduce(math.max);

    if (maxAvg == 0) return Success(image);

    final scaleR = maxAvg / avgR;
    final scaleG = maxAvg / avgG;
    final scaleB = maxAvg / avgB;

    final corrected = img.Image(width: image.width, height: image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = (p.r.toInt() * scaleR).round().clamp(0, 255);
        final g = (p.g.toInt() * scaleG).round().clamp(0, 255);
        final b = (p.b.toInt() * scaleB).round().clamp(0, 255);
        corrected.setPixelRgba(x, y, r, g, b, p.a.toInt());
      }
    }

    return Success(corrected);
  }

  /// Apply a gentle 3×3 Gaussian blur (σ ≈ 0.5) to [image].
  img.Image reduceNoise(img.Image image, {double sigma = 0.5}) {
    // Build a 3×3 Gaussian kernel.
    final kernel = _gaussianKernel3x3(sigma);
    return _convolve3x3(image, kernel);
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  Future<Result<img.Image>> _loadImage(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return AppError(
        AnalysisFailure('Image file not found at path: $path'),
      );
    }

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      return AppError(
        AnalysisFailure('Unable to decode image at path: $path'),
      );
    }
    return Success(image);
  }

  /// Basic image quality checks.
  Result<void> _checkImageQuality(img.Image image) {
    double sumLuma = 0;
    const sampleStep = 8;
    int count = 0;

    for (var y = 0; y < image.height; y += sampleStep) {
      for (var x = 0; x < image.width; x += sampleStep) {
        final p = image.getPixel(x, y);
        sumLuma += 0.299 * p.r.toInt() +
            0.587 * p.g.toInt() +
            0.114 * p.b.toInt();
        count++;
      }
    }

    if (count == 0) return const Success(null);
    final avgLuma = sumLuma / count;

    if (avgLuma < 30) {
      return const AppError(
        AnalysisFailure(
          'The image is too dark. Please improve lighting or turn on the flash.',
        ),
      );
    }
    if (avgLuma > 230) {
      return const AppError(
        AnalysisFailure(
          'The image is too bright. Please reduce lighting or turn off the flash.',
        ),
      );
    }
    return const Success(null);
  }

  /// Segment the preprocessed strip image and extract LAB colour from each pad.
  List<PadResult> _segmentAndExtract(img.Image strip, StripLayout layout) {
    final results = <PadResult>[];

    for (final pad in layout.pads) {
      // Map relative positions to pixel coordinates.
      final padX = ((0.5 - pad.relativeWidth / 2) * strip.width).round();
      final padY = ((pad.relativePosition) * strip.height).round();
      final padW =
          (pad.relativeWidth * strip.width).round().clamp(1, strip.width);
      final padH =
          (pad.relativeHeight * strip.height).round().clamp(1, strip.height);

      // Clamp to image bounds.
      final cropX = padX.clamp(0, strip.width - 1);
      final cropY = padY.clamp(0, strip.height - 1);
      final cropW = padW.clamp(1, strip.width - cropX);
      final cropH = padH.clamp(1, strip.height - cropY);

      final padImage = img.copyCrop(
        strip,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final labColor = _colorExtractor.extractMedianLab(padImage);
      final confidence = _colorExtractor.calculateConfidence(padImage);

      _log('  Pad ${pad.index} (${pad.parameterName}): '
          'L=${labColor.l.toStringAsFixed(1)} '
          'a=${labColor.a.toStringAsFixed(1)} '
          'b=${labColor.b.toStringAsFixed(1)} '
          'conf=${confidence.toStringAsFixed(2)}');

      results.add(PadResult(
        padIndex: pad.index,
        parameterName: pad.parameterName,
        labValues: labColor,
        confidenceScore: confidence,
        padImage: debugMode ? padImage : null,
      ));
    }

    return results;
  }

  /// Build a normalised 3×3 Gaussian kernel for the given [sigma].
  List<double> _gaussianKernel3x3(double sigma) {
    final kernel = List<double>.filled(9, 0.0);
    double sum = 0.0;
    for (var ky = -1; ky <= 1; ky++) {
      for (var kx = -1; kx <= 1; kx++) {
        final val = math.exp(-(kx * kx + ky * ky) / (2 * sigma * sigma));
        kernel[(ky + 1) * 3 + (kx + 1)] = val;
        sum += val;
      }
    }
    return kernel.map((v) => v / sum).toList();
  }

  /// Apply a 3×3 convolution kernel to [image].
  img.Image _convolve3x3(img.Image image, List<double> kernel) {
    final out = img.Image(width: image.width, height: image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        double r = 0, g = 0, b = 0;
        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final sx = (x + kx).clamp(0, image.width - 1);
            final sy = (y + ky).clamp(0, image.height - 1);
            final p = image.getPixel(sx, sy);
            final w = kernel[(ky + 1) * 3 + (kx + 1)];
            r += p.r.toInt() * w;
            g += p.g.toInt() * w;
            b += p.b.toInt() * w;
          }
        }
        final src = image.getPixel(x, y);
        out.setPixelRgba(
          x, y,
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          b.round().clamp(0, 255),
          src.a.toInt(),
        );
      }
    }
    return out;
  }

  void _log(String message) {
    if (debugMode) {
      // ignore: avoid_print
      print('[ImageProcessingService] $message');
    }
  }
}
