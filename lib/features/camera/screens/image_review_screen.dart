import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Review screen shown after capturing a photo.
///
/// The user can either proceed with the captured photo ("Use Photo") or
/// discard it and retake ("Retake").
class ImageReviewScreen extends StatelessWidget {
  const ImageReviewScreen({super.key, required this.imagePath});

  /// Absolute file-system path of the captured PNG image.
  final String imagePath;

  static const String routeName = '/camera/review';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen photo preview.
          Image.file(
            File(imagePath),
            fit: BoxFit.cover,
          ),

          // Semi-transparent gradient at the bottom for button legibility.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // Action buttons.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  children: [
                    // Retake button.
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Use Photo button.
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pushNamedAndRemoveUntil(
                          '/analysis',
                          (route) => route.isFirst,
                          arguments: imagePath,
                        ),
                        child: const Text('Use Photo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Back arrow (top-left).
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
