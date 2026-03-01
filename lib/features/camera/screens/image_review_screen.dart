import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';

/// Displays the captured photo and lets the user confirm or retake it.
///
/// - **"Use Photo"** navigates to the analysis route (placeholder until
///   Prompt 3 is implemented), passing [imagePath] as the route argument.
/// - **"Retake"** pops back to [CameraCaptureScreen].
class ImageReviewScreen extends StatelessWidget {
  const ImageReviewScreen({super.key, required this.imagePath});

  /// Absolute path to the captured PNG image file.
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Review Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Full-screen image preview.
          Expanded(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),

          // Action buttons.
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _usePhoto(context),
                    child: const Text('Use Photo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Navigates to the analysis screen, removing intermediate routes.
  ///
  /// The [imagePath] is passed as the route argument so the analysis module
  /// (Prompt 3) can locate the captured PNG.
  void _usePhoto(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.analysis,
      (route) => route.isFirst,
      arguments: imagePath,
    );
  }
}
