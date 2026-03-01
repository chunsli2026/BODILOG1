import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/tremor_providers.dart';

/// Non-dismissible medical disclaimer dialog.
///
/// Must be acknowledged before using the tremor analysis feature.
/// On first use, stores the acknowledgment in [FlutterSecureStorage].
class MedicalDisclaimerDialog extends StatelessWidget {
  const MedicalDisclaimerDialog({super.key});

  /// The full disclaimer text shown to the user.
  static const String disclaimerText =
      '⚠️ Medical Disclaimer: This tremor analysis tool is for '
      'informational and research purposes only. It is NOT a medical '
      'device and has NOT been cleared or approved by the FDA or any '
      'regulatory authority. Results should NOT be used to diagnose, '
      'treat, or manage Parkinson\'s disease or any other medical '
      'condition. Always consult a qualified healthcare professional '
      'for medical advice, diagnosis, and treatment. The UPDRS scores '
      'displayed are algorithmic approximations and may not reflect '
      'clinical assessments.';

  /// Shows the disclaimer dialog and returns `true` once acknowledged.
  ///
  /// [barrierDismissible] is always `false` — the dialog cannot be
  /// closed by tapping outside.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MedicalDisclaimerDialog(),
    );
    return result ?? false;
  }

  /// Shows the dialog only if the user has not yet acknowledged it.
  ///
  /// Stores acknowledgment in [FlutterSecureStorage] on first use.
  static Future<void> showIfNeeded(BuildContext context) async {
    const storage = FlutterSecureStorage();
    final value = await storage.read(key: 'tremor_disclaimer_acknowledged');
    if (value != 'true') {
      if (!context.mounted) return;
      final acknowledged = await show(context);
      if (acknowledged) {
        await acknowledgeDisclaimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text(
          'Medical Disclaimer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            disclaimerText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}
