import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/utils/qr_invitation_parser.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

/// Camera permission state for [QrScannerDialog].
enum CameraPermissionState { undetermined, granted, denied }

/// Modal dialog for scanning QR invitations with camera permission handling
/// and fallback to manual code entry.
class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({
    super.key,
    required this.onScanned,
    this.initialPermission = CameraPermissionState.undetermined,
    this.scannerBuilder,
  });

  /// Callback when a valid invitation code is obtained.
  final ValueChanged<String> onScanned;

  /// Initial permission override for testing and custom injection.
  final CameraPermissionState initialPermission;

  /// Custom scanner widget builder for widget tests or platform mock injection.
  final Widget Function(
    BuildContext context, {
    required ValueChanged<String> onDetect,
    required VoidCallback onPermissionDenied,
  })?
  scannerBuilder;

  /// Display the QR scanner dialog and return the scanned code.
  static Future<String?> show(
    BuildContext context, {
    CameraPermissionState initialPermission =
        CameraPermissionState.undetermined,
    Widget Function(
      BuildContext context, {
      required ValueChanged<String> onDetect,
      required VoidCallback onPermissionDenied,
    })?
    scannerBuilder,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => QrScannerDialog(
        initialPermission: initialPermission,
        scannerBuilder: scannerBuilder,
        onScanned: (code) => Navigator.of(dialogContext).pop(code),
      ),
    );
  }

  /// MSG46 constant for camera permission denial.
  static const String msg46 =
      'Camera permission is required to scan QR codes. Please enable it in Settings or enter the code manually.';

  /// MSG56 constant for invalid/unsupported invitation QR payloads.
  static const String msg56 =
      'This invitation is invalid, expired, or no longer available. Please check the invitation and try again.';

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  late CameraPermissionState _permissionState;
  MobileScannerController? _scannerController;
  final _manualCodeController = TextEditingController();
  String? _error;
  bool _isProcessingCode = false;

  @override
  void initState() {
    super.initState();
    _permissionState = widget.initialPermission;

    if (widget.scannerBuilder == null &&
        _permissionState != CameraPermissionState.denied) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _handleBarcodeDetected(String rawValue) {
    if (_isProcessingCode) return;

    final parsed = QrInvitationParser.parse(rawValue);
    if (parsed == null) {
      setState(() {
        _error = QrScannerDialog.msg56;
      });
      return;
    }

    _isProcessingCode = true;
    widget.onScanned(parsed);
  }

  void _handlePermissionDenied() {
    setState(() {
      _permissionState = CameraPermissionState.denied;
      _error = null;
    });
  }

  void _handleManualRedeem() {
    if (_isProcessingCode) return;

    final raw = _manualCodeController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _error = 'Please enter an invitation code.';
      });
      return;
    }

    final parsed = QrInvitationParser.parse(raw);
    final codeToUse = parsed ?? (raw.length == 8 ? raw.toUpperCase() : null);

    if (codeToUse == null) {
      setState(() {
        _error = QrScannerDialog.msg56;
      });
      return;
    }

    _isProcessingCode = true;
    widget.onScanned(codeToUse);
  }

  @override
  Widget build(BuildContext context) {
    final isPermissionDenied = _permissionState == CameraPermissionState.denied;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner, color: AppColors.primary),
          SizedBox(width: AppSpacing.sm),
          Text('Scan QR Invitation'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isPermissionDenied) ...[
                // Camera Permission Denied View (MSG46)
                Container(
                  key: const Key('camera_permission_denied_view'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.videocam_off_rounded,
                        size: 40,
                        color: AppColors.muted,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        QrScannerDialog.msg46,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.ink,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Camera Scanner View
                Container(
                  key: const Key('camera_scanner_view'),
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.scannerBuilder != null
                      ? widget.scannerBuilder!(
                          context,
                          onDetect: _handleBarcodeDetected,
                          onPermissionDenied: _handlePermissionDenied,
                        )
                      : MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            for (final barcode in capture.barcodes) {
                              final raw = barcode.rawValue;
                              if (raw != null && raw.isNotEmpty) {
                                _handleBarcodeDetected(raw);
                                break;
                              }
                            }
                          },
                          errorBuilder: (context, error) {
                            if (error.errorCode ==
                                MobileScannerErrorCode.permissionDenied) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _handlePermissionDenied();
                              });
                            }
                            return Container(
                              color: Colors.black87,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: const Text(
                                QrScannerDialog.msg46,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Manual Code Input Section (always available)
              Text(
                isPermissionDenied
                    ? 'Enter invitation code manually:'
                    : 'Or enter code manually:',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppTextField(
                key: const Key('manual_qr_input_field'),
                label: 'Invitation Code / Payload',
                controller: _manualCodeController,
                helperText: '8-character code or tripmate:// payload',
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error!,
                  key: const Key('qr_scanner_error_text'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Redeem',
          onPressed: _isProcessingCode ? null : _handleManualRedeem,
        ),
      ],
    );
  }
}
