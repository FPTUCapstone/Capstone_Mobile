import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/utils/qr_invitation_parser.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

/// Modal dialog for scanning or entering QR invitation payloads.
class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key, required this.onScanned});

  final ValueChanged<String> onScanned;

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => QrScannerDialog(
        onScanned: (code) => Navigator.of(dialogContext).pop(code),
      ),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleRedeem() {
    final raw = _controller.text.trim();
    final parsed = QrInvitationParser.parse(raw);
    if (parsed == null) {
      setState(() {
        _error =
            'This invitation is invalid, expired, or no longer available. Please check the invitation and try again.';
      });
      return;
    }
    widget.onScanned(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner),
          SizedBox(width: AppSpacing.sm),
          Text('Scan QR Invitation'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Point your camera at a TripMate QR code, or enter the scanned QR payload below:',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Scanned QR Payload',
              controller: _controller,
              helperText: 'tripmate://groups/join?code=<INVITE_CODE>',
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(label: 'Redeem', onPressed: _handleRedeem),
      ],
    );
  }
}
