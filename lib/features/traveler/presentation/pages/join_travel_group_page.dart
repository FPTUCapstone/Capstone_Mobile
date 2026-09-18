import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/qr_scanner_dialog.dart';
import 'package:trip_mate_mobile/features/traveler/utils/qr_invitation_parser.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

/// Screen for UC-23: Join Shared Group Trip.
class JoinTravelGroupPage extends StatefulWidget {
  const JoinTravelGroupPage({super.key, this.scannerLauncher});

  final Future<String?> Function(BuildContext)? scannerLauncher;

  @override
  State<JoinTravelGroupPage> createState() => _JoinTravelGroupPageState();
}

class _JoinTravelGroupPageState extends State<JoinTravelGroupPage> {
  final _codeController = TextEditingController();
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      if (_inlineError != null) {
        setState(() => _inlineError = null);
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleManualSubmit() async {
    final code = _codeController.text;
    await context.read<JoinTravelGroupCubit>().submit(code);
  }

  Future<void> _handleScanQr() async {
    final cubit = context.read<JoinTravelGroupCubit>();
    if (cubit.state.isSubmitting) return;

    final String? scannedData;
    if (widget.scannerLauncher != null) {
      scannedData = await widget.scannerLauncher!(context);
    } else {
      scannedData = await QrScannerDialog.show(context);
    }

    if (!mounted) return;
    if (scannedData != null) {
      if (cubit.state.isSubmitting) return;
      _codeController.text = scannedData;
      await cubit.submit(scannedData);
    }
  }

  Future<void> _handlePasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;

    final parsedCode = QrInvitationParser.parse(text);
    final codeToUse =
        parsedCode ??
        (text.length <= 8
            ? text.toUpperCase()
            : text.substring(0, 8).toUpperCase());

    _codeController.text = codeToUse;
    _codeController.selection = TextSelection.fromPosition(
      TextPosition(offset: _codeController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JoinTravelGroupCubit, JoinTravelGroupState>(
      listener: (context, state) {
        switch (state.status) {
          case JoinTravelGroupStatus.validationFailure:
            setState(() => _inlineError = state.errorMessage);
          case JoinTravelGroupStatus.failure:
            if (state.existingGroupId != null) {
              setState(() => _inlineError = null);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ??
                        'You are already a member of this travel group.',
                  ),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 3),
                ),
              );
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                router.go(
                  '${AppRoutes.travelerTravelGroups}/${state.existingGroupId}',
                );
              }
            } else {
              setState(() => _inlineError = state.errorMessage);
            }
          case JoinTravelGroupStatus.success:
            setState(() => _inlineError = null);
            final group = state.result;
            if (group != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('You have joined "${group.name}"!'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 3),
                ),
              );

              final router = GoRouter.maybeOf(context);
              if (router != null) {
                router.go(
                  '${AppRoutes.travelerTravelGroups}/${group.id}',
                  extra: group,
                );
              }
            }
          case JoinTravelGroupStatus.initial:
          case JoinTravelGroupStatus.submitting:
            break;
        }
      },
      builder: (context, state) {
        final isSubmitting = state.isSubmitting;

        return AppPageScaffold(
          title: 'Join Shared Group Trip',
          content: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Join your travel group using an 8-character invitation code or scan a QR invitation.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Manual code input
            AppTextField(
              label: 'Invitation code',
              controller: _codeController,
              enabled: !isSubmitting,
              helperText: 'Enter 8-character code (e.g. HOIAN8KP)',
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(8),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                _UpperCaseTextFormatter(),
              ],
              suffix: IconButton(
                tooltip: 'Paste from clipboard',
                icon: const Icon(Icons.content_paste_rounded, size: 20),
                onPressed: isSubmitting ? null : _handlePasteFromClipboard,
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.md),

            // Primary Join Button
            AppButton(
              label: 'Join Group',
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : _handleManualSubmit,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Centered "or" separator
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'or',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Secondary Scan QR Action Card
            OutlinedButton.icon(
              onPressed: isSubmitting ? null : _handleScanQr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan QR Invitation'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                side: BorderSide(
                  color: isSubmitting ? AppColors.line : AppColors.primary,
                ),
              ),
            ),

            // Inline Error Alert
            if (_inlineError != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppAlert(message: _inlineError!, type: AppAlertType.error),
            ],
          ],
        );
      },
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
