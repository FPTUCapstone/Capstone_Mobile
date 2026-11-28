import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/cubit/operator_contract_cubit.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/widgets/contract_pdf_view.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/widgets/contract_signature_pad.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';

typedef ContractPdfBuilder =
    Widget Function(
      Uint8List bytes,
      VoidCallback onOpened,
      VoidCallback onFailure,
    );

class OperatorContractPage extends StatefulWidget {
  const OperatorContractPage({this.pdfBuilder, super.key});
  final ContractPdfBuilder? pdfBuilder;
  @override
  State<OperatorContractPage> createState() => _OperatorContractPageState();
}

class _OperatorContractPageState extends State<OperatorContractPage>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _title = TextEditingController(),
      _capacity = TextEditingController(),
      _otp = TextEditingController();
  Timer? _ticker;
  String? _identityContractId;
  bool _reloadingSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      context.read<OperatorContractCubit>().load(
        reconcileSignedSession: context
            .read<AuthSessionCubit>()
            .state
            .awaitsContractSignature,
      ),
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        context.read<OperatorContractCubit>().load(
          reconcileSignedSession: context
              .read<AuthSessionCubit>()
              .state
              .awaitsContractSignature,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    for (final controller in [_name, _title, _capacity, _otp]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Vui lòng điền thông tin này.'
      : null;

  Future<void> _reloadSession() async {
    if (_reloadingSession) return;
    _reloadingSession = true;
    try {
      await context.read<AuthSessionCubit>().reloadRenewedOperatorSession();
      if (mounted &&
          context.read<AuthSessionCubit>().state.hasOperatorWorkspaceAccess) {
        context.go(AppRoutes.operator);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hợp đồng đã được lưu. Chưa thể cập nhật phiên đăng nhập, vui lòng thử lại.',
            ),
          ),
        );
      }
    } finally {
      _reloadingSession = false;
    }
  }

  Future<void> _share(Uint8List bytes, OperatorContract contract) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name:
                  'TripMate-contract-${contract.id}${contract.isSigned ? '-signed' : ''}.pdf',
            ),
          ],
          fileNameOverrides: [
            'TripMate-contract-${contract.id}${contract.isSigned ? '-signed' : ''}.pdf',
          ],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể chia sẻ PDF. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<OperatorContractCubit, OperatorContractState>(
    listener: (context, state) {
      final contract = state.contract;
      if (contract != null && _identityContractId != contract.id) {
        _identityContractId = contract.id;
        _name.text = contract.signerName;
        _title.text = contract.signerTitle;
        _capacity.text = contract.signerCapacity;
      }
      if (state.challenge == null || state.challengeExhausted) _otp.clear();
      if (state.sessionRenewed) unawaited(_reloadSession());
    },
    builder: (context, state) {
      final c = context.tmColors;
      final cubit = context.read<OperatorContractCubit>();
      final contract = state.contract;
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppCoastalAppBar(
          title: 'Hợp đồng đối tác',
          actions: [
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: state.busy
                  ? null
                  : context.read<AuthSessionCubit>().signOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (state.loading && contract == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: c.brandTeal),
                  ),
                )
              else if (contract == null) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: c.tealSoftContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            size: 28,
                            color: c.brandTeal,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        state.error ??
                            'Chưa có hợp đồng cần ký cho tài khoản này.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textPrimary, height: 1.45),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: cubit.load,
                        child: const Text('Tải lại'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: () =>
                            context.go(AppRoutes.operatorApplication),
                        child: const Text('Xem hồ sơ đăng ký'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: c.tealSoftContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.gavel_rounded,
                              color: c.brandTeal,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contract.title,
                                  style: TextStyle(
                                    fontFamily: AppTypography.displayFont,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${contract.companyName} · Phiên bản ${contract.templateVersion}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Builder(
                        builder: (_) {
                          final (label, fg, bg) = contract.isSigned
                              ? (
                                  'Đã ký hợp đồng',
                                  c.success,
                                  c.successContainer,
                                )
                              : contract.status == OperatorContractStatus.voided
                              ? (
                                  'Hợp đồng không còn hiệu lực ký',
                                  c.error,
                                  c.errorContainer,
                                )
                              : (
                                  'Chờ xác nhận và ký hợp đồng',
                                  c.warning,
                                  c.warningContainer,
                                );
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(
                                TripMateRadius.pill,
                              ),
                              border: Border.all(
                                color: fg.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                          );
                        },
                      ),
                      if (contract.signedAtUtc case final signedAt?) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Ngày ký ${formatCalendarDate(signedAt.toUtc().add(const Duration(hours: 7)))}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (state.error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Semantics(
                      liveRegion: true,
                      child: AppAlert(type: AppAlertType.error, message: error),
                    ),
                  ),
                if (state.notice case final notice?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Semantics(
                      liveRegion: true,
                      child: AppAlert(type: AppAlertType.info, message: notice),
                    ),
                  ),
                if (contract.canPrepare) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppSectionCard(
                    title: 'Thông tin người đại diện ký',
                    icon: Icons.badge_outlined,
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Điền đúng người có thẩm quyền đại diện doanh nghiệp. Hệ thống không mặc định người liên hệ là người đại diện pháp luật.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _name,
                            enabled: !state.busy,
                            maxLength: 150,
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên người ký',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextFormField(
                            controller: _title,
                            enabled: !state.busy,
                            maxLength: 150,
                            decoration: const InputDecoration(
                              labelText: 'Chức vụ',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextFormField(
                            controller: _capacity,
                            enabled: !state.busy,
                            maxLength: 500,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText:
                                  'Tư cách đại diện hoặc căn cứ ủy quyền',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: state.busy
                                ? null
                                : () {
                                    if (_form.currentState?.validate() ==
                                        true) {
                                      cubit.prepare(
                                        signerName: _name.text,
                                        signerTitle: _title.text,
                                        signerCapacity: _capacity.text,
                                      );
                                    }
                                  },
                            child: Text(
                              state.busy
                                  ? 'Đang tạo hợp đồng…'
                                  : 'Xác nhận thông tin và tạo PDF',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (contract.documentState ==
                    OperatorContractDocumentState.processing) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            color: c.brandTeal,
                            backgroundColor: c.surfaceElevated,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Đang chuẩn bị PDF hợp đồng với thông tin của bạn.',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (state.pollPaused)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: cubit.retryProcessing,
                              child: const Text('Kiểm tra lại kết quả'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (contract.documentState ==
                    OperatorContractDocumentState.failed) ...[
                  const SizedBox(height: AppSpacing.md),
                  const AppAlert(
                    type: AppAlertType.error,
                    message:
                        'Chưa thể tạo tài liệu. Vui lòng thử lại hoặc liên hệ hỗ trợ.',
                  ),
                ],
                if (contract.isSigned ||
                    contract.documentState ==
                        OperatorContractDocumentState.ready) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppSectionCard(
                    title: 'Tài liệu hợp đồng PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: state.busy || state.documentLoading
                              ? null
                              : cubit.openDocument,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(
                            state.documentLoading
                                ? 'Đang tải PDF…'
                                : contract.isSigned
                                ? 'Mở hợp đồng đã ký'
                                : 'Mở và kiểm tra PDF hợp đồng',
                          ),
                        ),
                        if (state.document case final bytes?) ...[
                          const SizedBox(height: AppSpacing.sm),
                          widget.pdfBuilder?.call(
                                bytes,
                                cubit.markDocumentReviewed,
                                cubit.documentViewFailed,
                              ) ??
                              ContractPdfView(
                                key: ValueKey(
                                  '${contract.id}-${contract.isSigned}-${contract.acceptedContentSha256}',
                                ),
                                bytes: bytes,
                                onOpened: cubit.markDocumentReviewed,
                                onFailure: cubit.documentViewFailed,
                              ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: () => _share(bytes, contract),
                            icon: const Icon(Icons.download),
                            label: const Text('Tải hoặc chia sẻ PDF'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (contract.canSign) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppSectionCard(
                    title: 'Ký xác nhận hợp đồng',
                    icon: Icons.draw_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Người ký ${contract.signerName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chức vụ ${contract.signerTitle}',
                          style: TextStyle(color: c.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tư cách đại diện ${contract.signerCapacity}',
                          style: TextStyle(color: c.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: state.consent,
                            onChanged: !state.documentReviewed || state.busy
                                ? null
                                : (value) => cubit.setConsent(value == true),
                            title: const Text(
                              'Tôi đã xem đúng bản hợp đồng này và đồng ý với nội dung bằng tư cách đại diện nêu trên.',
                            ),
                          ),
                        ),
                        if (!state.documentReviewed)
                          const Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppAlert(
                              type: AppAlertType.info,
                              message:
                                  'Mở PDF thành công trước khi xác nhận và ký.',
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        ContractSignaturePad(
                          key: ValueKey(
                            '${contract.id}-${contract.acceptedContentSha256}-${state.drawingRevision}',
                          ),
                          disabled: state.busy || !state.documentReviewed,
                          onChanged: cubit.setSignature,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: cubit.canRequestOtp
                              ? cubit.requestOtp
                              : null,
                          child: Text(
                            state.challenge == null
                                ? 'Gửi mã xác nhận đến email'
                                : 'Gửi lại mã xác nhận',
                          ),
                        ),
                        if (state.challenge case final challenge?) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Mã được gửi đến ${challenge.maskedEmail}. Còn ${challenge.expiresAtUtc.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 86400)} giây. Tối đa ${contract.otpPolicy.maxFailedAttempts} lần nhập sai.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          if (DateTime.now().toUtc().isBefore(
                            challenge.resendAtUtc,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Có thể gửi lại sau ${challenge.resendAtUtc.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 86400)} giây.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.textMuted,
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _otp,
                            enabled: !state.busy && !state.challengeExhausted,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Mã xác nhận gồm 6 chữ số',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: state.busy || state.challengeExhausted
                                ? null
                                : () => cubit.submit(_otp.text),
                            child: Text(
                              state.busy
                                  ? 'Đang xác nhận…'
                                  : 'Xác nhận ký hợp đồng',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (contract.isSigned &&
                    !state.sessionRenewed &&
                    !context
                        .watch<AuthSessionCubit>()
                        .state
                        .hasOperatorWorkspaceAccess) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.tonal(
                    onPressed: () => cubit.renewSignedSession(),
                    child: const Text('Cập nhật phiên đăng nhập'),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: state.busy ? null : cubit.load,
                  child: const Text('Làm mới trạng thái hợp đồng'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
