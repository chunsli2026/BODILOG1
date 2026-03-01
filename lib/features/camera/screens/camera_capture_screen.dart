import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/permissions/permission_service.dart';
import '../providers/camera_provider.dart';
import '../widgets/camera_overlay_guide.dart';
import '../widgets/capture_button.dart';
import '../widgets/flash_toggle_button.dart';
import 'image_review_screen.dart';

/// Full-screen camera capture screen used for photographing urine test strips.
class CameraCaptureScreen extends ConsumerStatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  ConsumerState<CameraCaptureScreen> createState() =>
      _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen>
    with WidgetsBindingObserver {
  final _permissionService = const PermissionService();
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose the controller when leaving the screen.
    ref.read(cameraProvider.notifier).dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final cameraState = ref.read(cameraProvider);
    if (cameraState.controller == null) return;

    if (state == AppLifecycleState.inactive) {
      ref.read(cameraProvider.notifier).dispose();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(cameraProvider.notifier).initializeCamera();
    }
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<void> _checkPermission() async {
    if (_permissionChecked) return;
    _permissionChecked = true;

    final result = await _permissionService.requestCameraPermission();
    if (!mounted) return;

    if (result.isSuccess) {
      ref.read(cameraProvider.notifier).initializeCamera();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'BodiLog needs camera access to photograph your test strip. '
          'Please grant the permission in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Open app settings via permission_handler.
              _openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    // After returning from settings, re-check permission.
    if (mounted) {
      _permissionChecked = false;
      _checkPermission();
    }
  }

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  Future<void> _onCapture() async {
    await ref.read(cameraProvider.notifier).captureImage();
    if (!mounted) return;

    final cameraState = ref.read(cameraProvider);
    if (cameraState.capturedImagePath != null) {
      final path = cameraState.capturedImagePath!;
      ref.read(cameraProvider.notifier).clearCapturedImage();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ImageReviewScreen(imagePath: path),
        ),
      );
    } else if (cameraState.failure != null) {
      _showError(cameraState.failure!.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tap-to-focus
  // ---------------------------------------------------------------------------

  void _onTapToFocus(TapDownDetails details, BoxConstraints constraints) {
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;
    ref.read(cameraProvider.notifier).lockExposure(x, y);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview or loading/error state.
          if (cameraState.isInitialising)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (cameraState.failure != null && cameraState.controller == null)
            _ErrorView(
              message: cameraState.failure!.message,
              onRetry: () =>
                  ref.read(cameraProvider.notifier).initializeCamera(),
            )
          else if (cameraState.isReady)
            _CameraPreview(
              controller: cameraState.controller!,
              onTapDown: _onTapToFocus,
            )
          else
            const SizedBox.shrink(),

          // Overlay guide (shown when preview is ready).
          if (cameraState.isReady)
            const CameraOverlayGuide(),

          // Loading overlay during capture.
          if (cameraState.isCapturing)
            const ColoredBox(
              color: Colors.black45,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Top controls bar.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FlashToggleButton(
                  flashMode: cameraState.flashMode,
                  onToggle: () =>
                      ref.read(cameraProvider.notifier).toggleFlash(),
                ),
              ),
            ),
          ),

          // Capture button at the bottom.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: CaptureButton(
                  isCapturing: cameraState.isCapturing,
                  onPressed:
                      cameraState.isReady && !cameraState.isCapturing
                          ? _onCapture
                          : null,
                ),
              ),
            ),
          ),

          // Back button (top-left).
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({
    required this.controller,
    required this.onTapDown,
  });

  final CameraController controller;
  final void Function(TapDownDetails, BoxConstraints) onTapDown;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (d) => onTapDown(d, constraints),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize?.height ?? 1,
                height: controller.value.previewSize?.width ?? 1,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
