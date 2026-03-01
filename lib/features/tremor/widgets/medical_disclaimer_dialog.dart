import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tremor_providers.dart';

/// Modal disclaimer that must be acknowledged before tremor analysis can begin.
///
/// On first use this dialog is non-dismissible (the user must tap
/// "I Understand").  Pass [requireAcknowledgement] = `false` to show a
/// read-only version (e.g., on the results screen).
class MedicalDisclaimerDialog extends ConsumerStatefulWidget {
  const MedicalDisclaimerDialog({
    super.key,
    this.requireAcknowledgement = true,
  });

  final bool requireAcknowledgement;

  @override
  ConsumerState<MedicalDisclaimerDialog> createState() =>
      _MedicalDisclaimerDialogState();
}

class _MedicalDisclaimerDialogState
    extends ConsumerState<MedicalDisclaimerDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.requireAcknowledgement,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Medical Disclaimer',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚠️ This tremor analysis tool is for informational and '
                'research purposes only. It is NOT a medical device and has '
                'NOT been cleared or approved by the FDA or any regulatory '
                'authority.\n\n'
                'Results should NOT be used to diagnose, treat, or manage '
                "Parkinson's disease or any other medical condition. Always "
                'consult a qualified healthcare professional for medical '
                'advice, diagnosis, and treatment.\n\n'
                'The UPDRS scores displayed are algorithmic approximations '
                'and may not reflect clinical assessments.',
              ),
              if (widget.requireAcknowledgement) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _checked,
                      onChanged: (v) => setState(() => _checked = v ?? false),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'I understand this tool is not a medical device.',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.requireAcknowledgement)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          else
            ElevatedButton(
              onPressed: _checked
                  ? () async {
                      await acknowledgeDisclaimer();
                      if (context.mounted) Navigator.of(context).pop(true);
                    }
                  : null,
              child: const Text('I Understand'),
            ),
        ],
      ),
    );
  }
}

/// Show [MedicalDisclaimerDialog] and return `true` if acknowledged.
Future<bool> showMedicalDisclaimer(
  BuildContext context, {
  bool requireAcknowledgement = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MedicalDisclaimerDialog(
      requireAcknowledgement: requireAcknowledgement,
    ),
  );
  return result ?? false;
}
