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
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

/// Screen for UC-23: Join Shared Group Trip (Screen #62).
class JoinTravelGroupPage extends StatefulWidget {
  const JoinTravelGroupPage({
    super.key,
    this.scannerLauncher,
    this.isDemoMode = false,
  });

  final Future<String?> Function(BuildContext)? scannerLauncher;
  final bool isDemoMode;

  @override
  State<JoinTravelGroupPage> createState() => _JoinTravelGroupPageState();
}

class _JoinTravelGroupPageState extends State<JoinTravelGroupPage> {
  final _codeController = TextEditingController();
  String? _inlineError;
  bool _isScanning = false;
  bool _showDemoPanel = false;

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
    if (cubit.state.isSubmitting || _isScanning) return;

    setState(() => _isScanning = true);

    try {
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
    } finally {
      if (mounted) setState(() => _isScanning = false);
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
    final c = context.tmColors;
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
                        'Bạn đã là thành viên của nhóm du lịch này.',
                  ),
                  backgroundColor: c.brandTeal,
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
                  content: Text('Bạn đã tham gia "${group.name}"!'),
                  backgroundColor: c.success,
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
          title: 'Tham gia nhóm du lịch',
          actions: [
            if (widget.isDemoMode)
              IconButton(
                key: const Key('demo_controls_toggle_button'),
                icon: Icon(
                  _showDemoPanel ? Icons.bug_report : Icons.bug_report_outlined,
                  color: _showDemoPanel ? c.warning : null,
                ),
                tooltip: 'Bảng điều khiển demo',
                onPressed: () {
                  setState(() => _showDemoPanel = !_showDemoPanel);
                },
              ),
          ],
          content: [
            if (widget.isDemoMode && _showDemoPanel)
              _buildDemoControlsPanel(context),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.tealSoftContainer,
                    borderRadius: BorderRadius.circular(TripMateRadius.md),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: 26,
                    color: c.brandTeal,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Tham gia nhóm du lịch bằng mã mời 8 ký tự hoặc quét mã QR lời mời.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppSectionCard(
              title: 'Nhập mã mời',
              icon: Icons.vpn_key_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Mã mời',
                    controller: _codeController,
                    enabled: !isSubmitting,
                    helperText: 'Nhập mã gồm 8 ký tự (VD: HOIAN8KP)',
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(8),
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      _UpperCaseTextFormatter(),
                    ],
                    suffix: IconButton(
                      tooltip: 'Dán từ bộ nhớ tạm',
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      onPressed: isSubmitting
                          ? null
                          : _handlePasteFromClipboard,
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  if (_inlineError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppAlert(message: _inlineError!, type: AppAlertType.error),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Tham gia nhóm',
                    isLoading: isSubmitting,
                    onPressed: isSubmitting ? null : _handleManualSubmit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: Divider(color: c.borderSubtle)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'hoặc',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.textMuted),
                  ),
                ),
                Expanded(child: Divider(color: c.borderSubtle)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: isSubmitting || _isScanning ? null : _handleScanQr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Quét mã QR lời mời'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                side: BorderSide(
                  color: isSubmitting || _isScanning
                      ? c.borderSubtle
                      : c.brandTeal,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('cancel_button'),
              onPressed: isSubmitting
                  ? null
                  : () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.traveler);
                      }
                    },
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDemoControlsPanel(BuildContext context) {
    final c = context.tmColors;
    return Container(
      key: const Key('demo_controls_panel'),
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: c.warningContainer,
        borderRadius: BorderRadius.circular(TripMateRadius.lg),
        border: Border.all(color: c.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_circle_outlined, color: c.warning, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Điều khiển thử nghiệm (Demo)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: c.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              ActionChip(
                label: const Text('Giả lập mã hợp lệ (HOIAN8KP)'),
                onPressed: () {
                  _codeController.text = 'HOIAN8KP';
                  setState(() => _inlineError = null);
                },
              ),
              ActionChip(
                label: const Text('Giả lập mã hết hạn (EXPIRED8)'),
                onPressed: () {
                  _codeController.text = 'EXPIRED8';
                  setState(() => _inlineError = null);
                },
              ),
              ActionChip(
                label: const Text('Giả lập đã là thành viên (ALREADY8)'),
                onPressed: () {
                  _codeController.text = 'ALREADY8';
                  setState(() => _inlineError = null);
                },
              ),
              ActionChip(
                label: const Text('Giả lập lỗi máy chủ (SERVER12)'),
                onPressed: () {
                  _codeController.text = 'SERVER12';
                  setState(() => _inlineError = null);
                },
              ),
            ],
          ),
        ],
      ),
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
