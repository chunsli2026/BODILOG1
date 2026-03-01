import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme.dart';
import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../../core/permissions/permission_service.dart';
import '../providers/camera_provider.dart';
import '../widgets/camera_overlay_guide.dart';
import '../widgets/capture_button.dart';
import '../widgets/flash_toggle_button.dart';
import 'image_review_screen.dart';

/// Main camera capture screen for photographing urine test strips.
///
/// Checks camera permissions, initialises the [CameraController], and
/// provides the capture UI.  Navigates to [ImageReviewScreen] after a
/// successful capture.
class CameraCaptureScreen extends ConsumerStatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  ConsumerState<CameraCaptureScreen> createState() =>
      _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen>
    with WidgetsBindingObserver {
  bool _isCapturing = false;
  bool _permissionGranted = false;

  static const _permissionService = PermissionService();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAndRequestPermission(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose the controller when leaving this screen.
    ref.read(cameraControllerProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        ref.read(cameraControllerProvider.notifier).disposeCamera();
      case AppLifecycleState.resumed:
        if (_permissionGranted) {
          ref.read(cameraControllerProvider.notifier).initializeCamera();
        }
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Permission handling
  // ---------------------------------------------------------------------------

  Future<void> _checkAndRequestPermission() async {
    final result = await _permissionService.requestCameraPermission();
    if (!mounted) return;

    if (result is Success<bool>) {
      setState(() => _permissionGranted = true);
      await ref.read(cameraControllerProvider.notifier).initializeCamera();
    } else {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'BodiLog needs camera access to photograph urine test strips'
          ' for analysis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  Future<void> _onCapture(CameraController controller) async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    final result = await ref
        .read(cameraServiceProvider)
        .captureImage(controller);

    if (!mounted) return;
    setState(() => _isCapturing = false);

    switch (result) {
      case Success(data: final path):
        ref.read(capturedImagePathProvider.notifier).state = path;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ImageReviewScreen(imagePath: path),
          ),
        );
      case AppError(failure: final failure):
        _showError(failure.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Flash
  // ---------------------------------------------------------------------------

  Future<void> _onToggleFlash(CameraController controller) async {
    final current = ref.read(flashModeProvider);
    final result = await ref
        .read(cameraServiceProvider)
        .toggleFlash(controller, current);
    if (result is Success<FlashMode>) {
      ref.read(flashModeProvider.notifier).state = result.data;
    }
  }

  // ---------------------------------------------------------------------------
  // Tap-to-focus / exposure lock
  // ---------------------------------------------------------------------------

  Future<void> _onTapToFocus(
    TapDownDetails details,
    CameraController controller,
    BoxConstraints constraints,
  ) async {
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    // Lock exposure at the tapped point.
    await ref
        .read(cameraServiceProvider)
        .lockExposure(controller, Offset(x, y));

    // Also attempt to lock focus (silently ignore if unsupported).
    try {
      await controller.setFocusPoint(Offset(x, y));
      await controller.setFocusMode(FocusMode.locked);
    } catch (_) {
      // Some devices do not support tap-to-focus; fail silently.
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);
    final flashMode = ref.watch(flashModeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraState.when(
        data: (controller) {
          if (controller == null || !controller.value.isInitialized) {
            return _buildPermissionOrLoadingView();
          }
          return _buildCameraPreview(controller, flashMode);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (error, _) => _buildErrorView(error),
      ),
    );
  }

  Widget _buildPermissionOrLoadingView() {
    if (!_permissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Camera permission is required.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkAndRequestPermission,
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildErrorView(Object error) {
    final message = error is Failure
        ? error.message
        : 'Failed to initialise camera.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(cameraControllerProvider.notifier).initializeCamera(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(
    CameraController controller,
    FlashMode flashMode,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview — fills the screen and intercepts tap-to-focus.
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            onTapDown: (details) =>
                _onTapToFocus(details, controller, constraints),
            child: CameraPreview(controller),
          ),
        ),

        // Strip alignment overlay.
        const CameraOverlayGuide(),

        // Top bar: back button (left) and flash toggle (right).
        Positioned(
          top: MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              ),
              FlashToggleButton(
                flashMode: flashMode,
                onToggle: () => _onToggleFlash(controller),
              ),
            ],
          ),
        ),

        // Bottom: capture button.
        Positioned(
          bottom: 40 + MediaQuery.of(context).padding.bottom,
          left: 0,
          right: 0,
          child: Center(
            child: CaptureButton(
              onPressed: () => _onCapture(controller),
              isCapturing: _isCapturing,
            ),
          ),
        ),
      ],
    );
  }
}
