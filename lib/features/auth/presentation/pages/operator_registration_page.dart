import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_operator_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/services/operator_document_picker.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sticky_action_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class OperatorRegistrationPage extends StatefulWidget {
  const OperatorRegistrationPage({required this.documentPicker, super.key});

  final OperatorDocumentPicker documentPicker;

  @override
  State<OperatorRegistrationPage> createState() =>
      _OperatorRegistrationPageState();
}

class _OperatorRegistrationPageState extends State<OperatorRegistrationPage> {
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  final _controllers = <String, TextEditingController>{
    for (final field in [
      'email',
      'password',
      'confirmPassword',
      'companyName',
      'businessLicenseNo',
      'taxCode',
      'contactPerson',
      'businessAddress',
      'contactPhone',
    ])
      field: TextEditingController(),
  };

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return BlocBuilder<RegisterOperatorCubit, RegisterOperatorState>(
      buildWhen: (previous, current) =>
          previous.step != current.step ||
          previous.phase != current.phase ||
          previous.isBusy != current.isBusy ||
          previous.notice != current.notice ||
          !mapEquals(previous.errors, current.errors) ||
          previous.businessLicence != current.businessLicence ||
          !listEquals(
            previous.supportingDocuments,
            current.supportingDocuments,
          ) ||
          previous.acceptedTerms != current.acceptedTerms ||
          previous.emailSent != current.emailSent ||
          previous.alreadyVerified != current.alreadyVerified ||
          previous.resumeExistingIdentity != current.resumeExistingIdentity,
      builder: (context, state) {
        final content = switch (state.phase) {
          RegisterOperatorPhase.awaitingVerification => _verificationContent(
            state,
          ),
          RegisterOperatorPhase.submitted => _submittedContent(state),
          RegisterOperatorPhase.uncertain => _uncertainContent(state),
          RegisterOperatorPhase.editing => _wizardContent(state),
        };
        final footer = switch (state.phase) {
          RegisterOperatorPhase.editing => _wizardFooter(state),
          RegisterOperatorPhase.uncertain => _uncertainFooter(state),
          RegisterOperatorPhase.awaitingVerification => _verificationFooter(
            state,
          ),
          RegisterOperatorPhase.submitted => _submittedFooter(state),
        };
        return Scaffold(
          backgroundColor: c.canvas,
          appBar: AppCoastalAppBar(
            title: state.phase == RegisterOperatorPhase.awaitingVerification
                ? 'Xác minh email'
                : 'Đăng ký nhà điều hành tour',
          ),
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  children: content,
                ),
              ),
            ),
          ),
          bottomNavigationBar: AppStickyActionBar(
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: footer,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _wizardContent(RegisterOperatorState state) {
    final c = context.tmColors;
    final (stepTitle, stepIcon) = switch (state.step) {
      0 => ('1. Tài khoản', Icons.person_outline_rounded),
      1 => ('2. Doanh nghiệp', Icons.business_outlined),
      _ => ('3. Hồ sơ pháp lý', Icons.folder_copy_outlined),
    };
    return [
      Text(
        'Hoàn tất biểu mẫu, xác minh email rồi gửi hồ sơ đăng ký.',
        style: TextStyle(fontSize: 13.5, height: 1.4, color: c.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      _StepIndicator(step: state.step),
      const SizedBox(height: AppSpacing.md),
      if (state.notice != null) ...[
        AppAlert(message: state.notice!, type: AppAlertType.error),
        const SizedBox(height: AppSpacing.md),
      ],
      AppSectionCard(
        title: stepTitle,
        icon: stepIcon,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (state.step) {
            0 => _accountFields(state),
            1 => _companyFields(state),
            _ => _documentsFields(state),
          },
        ),
      ),
    ];
  }

  List<Widget> _accountFields(RegisterOperatorState state) {
    final c = context.tmColors;
    return [
      Container(
        decoration: BoxDecoration(
          color: c.canvas,
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          border: Border.all(color: c.borderSubtle),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
            ),
            activeColor: c.brandTeal,
            value: state.resumeExistingIdentity,
            onChanged: state.isBusy
                ? null
                : (value) => context
                      .read<RegisterOperatorCubit>()
                      .setResumeExistingIdentity(value ?? false),
            title: const Text('Tiếp tục đăng ký chưa hoàn tất'),
            subtitle: const Text(
              'Dùng cùng email và mật khẩu. Bạn sẽ cần nhập lại thông tin và chọn lại tài liệu.',
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _textField(
        state,
        'email',
        'Địa chỉ email',
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: AppSpacing.md),
      _passwordField(
        state,
        'password',
        'Mật khẩu',
        helperText:
            '8–72 ký tự gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt.',
      ),
      const SizedBox(height: AppSpacing.md),
      _passwordField(state, 'confirmPassword', 'Xác nhận mật khẩu'),
    ];
  }

  List<Widget> _companyFields(RegisterOperatorState state) => [
    _textField(state, 'companyName', 'Tên doanh nghiệp'),
    const SizedBox(height: AppSpacing.md),
    _textField(
      state,
      'businessLicenseNo',
      'Số giấy phép kinh doanh lữ hành',
      helperText: 'VD: 79-0123/2026/TCDL-GPLHQT hoặc 01-0456/2025/SDL-GPLHND',
    ),
    const SizedBox(height: AppSpacing.md),
    _textField(
      state,
      'taxCode',
      'Mã số thuế',
      helperText: '10 chữ số, hoặc 10 chữ số-3 chữ số cho chi nhánh',
    ),
    const SizedBox(height: AppSpacing.md),
    _textField(state, 'contactPerson', 'Người liên hệ'),
    const SizedBox(height: AppSpacing.md),
    _textField(state, 'businessAddress', 'Địa chỉ kinh doanh (không bắt buộc)'),
    const SizedBox(height: AppSpacing.md),
    _textField(
      state,
      'contactPhone',
      'Số điện thoại liên hệ (không bắt buộc)',
      keyboardType: TextInputType.phone,
    ),
  ];

  List<Widget> _documentsFields(RegisterOperatorState state) {
    final c = context.tmColors;
    return [
      Text(
        'Định dạng PDF, JPG hoặc PNG; tối đa 5 MB mỗi tệp.',
        style: TextStyle(fontSize: 12.5, color: c.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton.icon(
        onPressed: state.isBusy ? null : _pickLicence,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Chọn giấy phép kinh doanh'),
      ),
      if (state.businessLicence != null) ...[
        const SizedBox(height: AppSpacing.xs),
        _AttachedFilePill(fileName: state.businessLicence!.fileName),
      ],
      _inlineError(state, 'businessLicenseDocument'),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton.icon(
        onPressed: state.isBusy ? null : _pickSupporting,
        icon: const Icon(Icons.attach_file_outlined),
        label: const Text(
          'Chọn tài liệu bổ sung (không bắt buộc, tối đa 5 tệp)',
        ),
      ),
      if (state.supportingDocuments.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xs),
        for (final file in state.supportingDocuments) ...[
          _AttachedFilePill(fileName: file.fileName),
          const SizedBox(height: 4),
        ],
      ],
      _inlineError(state, 'supportingDocuments'),
      const SizedBox(height: AppSpacing.md),
      Container(
        decoration: BoxDecoration(
          color: c.canvas,
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          border: Border.all(color: c.borderSubtle),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: c.brandTeal,
            value: state.acceptedTerms,
            onChanged: state.isBusy
                ? null
                : (accepted) => context
                      .read<RegisterOperatorCubit>()
                      .setAcceptedTerms(accepted ?? false),
            title: const Text(
              'Tôi đồng ý với Điều khoản dịch vụ, Chính sách bảo mật và Thỏa thuận đối tác.',
            ),
          ),
        ),
      ),
      _inlineError(state, 'acceptTerms'),
      const SizedBox(height: AppSpacing.sm),
      const AppAlert(
        message:
            'Hồ sơ của bạn chỉ được gửi sau khi bạn xác minh email. Sau khi nộp, hồ sơ sẽ ở trạng thái Chờ phê duyệt cho đến khi quản trị viên xét duyệt.',
      ),
    ];
  }

  Widget _textField(
    RegisterOperatorState state,
    String key,
    String label, {
    TextInputType? keyboardType,
    String? helperText,
  }) => AppTextField(
    controller: _controllers[key],
    label: label,
    keyboardType: keyboardType,
    helperText: helperText,
    enabled: !state.isBusy,
    errorText: state.errors[key],
    textInputAction: TextInputAction.next,
    onChanged: (value) {
      // Vietnamese IMEs may replace their composing range on the next keystroke.
      // Clearing a validation error would rebuild this field mid-composition.
      final composing = _controllers[key]!.value.composing;
      if (composing.isValid && !composing.isCollapsed) return;
      context.read<RegisterOperatorCubit>().updateField(key, value);
    },
  );

  void _commitVisibleFields() {
    final cubit = context.read<RegisterOperatorCubit>();
    final keys = cubit.state.step == 0
        ? const ['email', 'password', 'confirmPassword']
        : const [
            'companyName',
            'businessLicenseNo',
            'taxCode',
            'contactPerson',
            'businessAddress',
            'contactPhone',
          ];
    for (final key in keys) {
      final value = _controllers[key]!.text;
      if (cubit.state.values[key] != value) cubit.updateField(key, value);
    }
  }

  void _nextStep() {
    _commitVisibleFields();
    context.read<RegisterOperatorCubit>().next();
  }

  void _previousStep() {
    _commitVisibleFields();
    context.read<RegisterOperatorCubit>().back();
  }

  Widget _passwordField(
    RegisterOperatorState state,
    String key,
    String label, {
    String? helperText,
  }) => AppPasswordField(
    controller: _controllers[key]!,
    label: label,
    enabled: !state.isBusy,
    errorText: state.errors[key],
    helperText: helperText,
    onChanged: (value) =>
        context.read<RegisterOperatorCubit>().updateField(key, value),
  );

  Widget _inlineError(RegisterOperatorState state, String key) {
    final message = state.errors[key];
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text(
        message,
        style: TextStyle(fontSize: 12.5, color: context.tmColors.error),
      ),
    );
  }

  Widget _wizardFooter(RegisterOperatorState state) {
    final cubit = context.read<RegisterOperatorCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isBusy)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Center(
              child: CircularProgressIndicator(
                color: context.tmColors.brandTeal,
              ),
            ),
          ),
        Row(
          children: [
            if (state.step > 0) ...[
              OutlinedButton(
                onPressed: state.isBusy ? null : _previousStep,
                child: const Text('Quay lại'),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: FilledButton(
                onPressed: state.isBusy
                    ? null
                    : state.step == 2
                    ? cubit.submit
                    : _nextStep,
                child: Text(
                  state.step == 2 ? 'Xác minh email trước' : 'Tiếp theo',
                ),
              ),
            ),
          ],
        ),
        if (state.step == 0)
          TextButton(
            onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
            child: const Text('Quay lại đăng nhập'),
          ),
        if (state.step == 0)
          TextButton(
            onPressed: state.isBusy
                ? null
                : () => context.push(AppRoutes.operatorEmailRecovery),
            child: const Text('Đã gửi hồ sơ? Hoàn tất xác minh email'),
          ),
      ],
    );
  }

  List<Widget> _uncertainContent(RegisterOperatorState state) => [
    const AppAlert(
      title: 'Chưa xác định được trạng thái đăng ký',
      message:
          'Máy chủ có thể đã lưu hồ sơ của bạn. Hãy giữ nguyên tài khoản Firebase này và không tự động gửi đăng ký mới.',
      type: AppAlertType.warning,
    ),
    if (state.notice != null) ...[
      const SizedBox(height: AppSpacing.md),
      AppAlert(message: state.notice!, type: AppAlertType.info),
    ],
  ];

  Widget _uncertainFooter(RegisterOperatorState state) {
    final cubit = context.read<RegisterOperatorCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isBusy)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Center(
              child: CircularProgressIndicator(
                color: context.tmColors.brandTeal,
              ),
            ),
          ),
        if (state.canRetryOriginal)
          FilledButton(
            onPressed: state.isBusy ? null : cubit.retryUnknownOutcome,
            child: const Text('Thử lại yêu cầu ban đầu với cùng tài khoản'),
          ),
        TextButton(
          onPressed: state.isBusy
              ? null
              : () => context.push(
                  AppRoutes.operatorEmailRecovery,
                  extra: state.values['email'],
                ),
          child: const Text('Đã gửi hồ sơ? Hoàn tất xác nhận email'),
        ),
        TextButton(
          onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
          child: const Text('Đăng nhập'),
        ),
      ],
    );
  }

  List<Widget> _verificationContent(RegisterOperatorState state) {
    final c = context.tmColors;
    return [
      AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: c.tealSoftContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_unread_outlined,
                size: 34,
                color: c.brandTeal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              state.alreadyVerified
                  ? 'Email đã được xác minh'
                  : 'Kiểm tra hộp thư của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.alreadyVerified
                  ? 'Email của bạn đã được xác minh. Hãy kiểm tra lại thông tin và gửi hồ sơ đăng ký bên dưới.'
                  : 'Mở liên kết xác minh trong email rồi quay lại đây để gửi hồ sơ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: c.textSecondary,
              ),
            ),
            if (_maskedEmail(state.values['email'])
                case final maskedEmail?) ...[
              const SizedBox(height: AppSpacing.md),
              Chip(
                avatar: Icon(Icons.mail_outline, size: 18, color: c.brandTeal),
                label: Text(maskedEmail),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      const AppAlert(
        title: 'Hồ sơ chưa được gửi',
        message:
            'Hãy giữ ứng dụng mở cho đến khi gửi xong. Nếu bạn thoát ra, hãy tiếp tục bằng cùng email, mật khẩu và chọn lại tài liệu.',
        type: AppAlertType.info,
      ),
      if (state.notice != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppAlert(
          message: state.notice!,
          type:
              state.notice ==
                      RegisterOperatorCubit.verificationEmailSentNotice ||
                  state.notice ==
                      RegisterOperatorCubit.emailAlreadyVerifiedNotice
              ? AppAlertType.info
              : AppAlertType.warning,
        ),
      ],
    ];
  }

  Widget _verificationFooter(RegisterOperatorState state) {
    final cubit = context.read<RegisterOperatorCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isBusy)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Center(
              child: CircularProgressIndicator(
                color: context.tmColors.brandTeal,
              ),
            ),
          ),
        FilledButton(
          onPressed: state.isBusy ? null : cubit.confirmVerifiedEmail,
          child: Text(
            state.alreadyVerified
                ? 'Gửi hồ sơ đăng ký'
                : 'Tôi đã xác minh email — Gửi hồ sơ',
          ),
        ),
        if (!state.alreadyVerified) ...[
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: state.isBusy || _resendSecondsLeft > 0
                ? null
                : _resendVerificationEmail,
            child: Text(
              _resendSecondsLeft > 0
                  ? 'Gửi lại sau ${_resendSecondsLeft}s'
                  : 'Gửi lại email xác minh',
            ),
          ),
        ],
        TextButton(
          onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
          child: const Text('Đăng nhập'),
        ),
      ],
    );
  }

  List<Widget> _submittedContent(RegisterOperatorState state) {
    final c = context.tmColors;
    return [
      AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: c.successContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.task_alt_outlined, size: 36, color: c.success),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Đã gửi hồ sơ đăng ký',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      const AppAlert(
        title: 'Chờ phê duyệt',
        message:
            'Quản trị viên cần xét duyệt hồ sơ trước khi bạn có thể đăng tour hoặc nhận đặt chỗ.',
        type: AppAlertType.success,
      ),
      if (state.notice != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppAlert(message: state.notice!, type: AppAlertType.warning),
      ],
    ];
  }

  Widget _submittedFooter(RegisterOperatorState state) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (state.outcome?.verificationSynced == false)
        TextButton(
          onPressed: () => context.push(
            AppRoutes.operatorEmailRecovery,
            extra: state.values['email'],
          ),
          child: const Text('Hoàn tất xác nhận email'),
        ),
      FilledButton(
        onPressed: () => context.go(AppRoutes.login),
        child: const Text('Đăng nhập'),
      ),
    ],
  );

  String? _maskedEmail(String? email) {
    if (email == null) return null;
    final separator = email.indexOf('@');
    if (separator <= 0 || separator == email.length - 1) return null;
    return '${email[0]}***${email.substring(separator)}';
  }

  Future<void> _resendVerificationEmail() async {
    await context.read<RegisterOperatorCubit>().resendEmail();
    if (!mounted) return;
    if (context.read<RegisterOperatorCubit>().state.notice !=
        RegisterOperatorCubit.verificationEmailSentNotice) {
      return;
    }
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  Future<void> _pickLicence() async {
    try {
      final files = await widget.documentPicker.pick(multiple: false);
      if (!mounted || files == null || files.isEmpty) return;
      context.read<RegisterOperatorCubit>().setBusinessLicence(files.first);
    } catch (_) {
      _showPickerError();
    }
  }

  Future<void> _pickSupporting() async {
    try {
      final files = await widget.documentPicker.pick(multiple: true);
      if (!mounted || files == null) return;
      context.read<RegisterOperatorCubit>().setSupportingDocuments(files);
    } catch (_) {
      _showPickerError();
    }
  }

  void _showPickerError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không thể đọc tệp đã chọn. Vui lòng thử lại.'),
      ),
    );
  }
}

class _AttachedFilePill extends StatelessWidget {
  const _AttachedFilePill({required this.fileName});
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.successContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: c.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    const labels = ['Tài khoản', 'Doanh nghiệp', 'Hồ sơ'];
    return Row(
      children: List.generate(3, (index) {
        final reached = index <= step;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Semantics(
              label:
                  'Bước ${index + 1} trên 3: ${labels[index]}${index == step ? ', hiện tại' : ''}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: reached ? 1 : 0,
                    minHeight: 6,
                    backgroundColor: c.borderSubtle,
                    color: c.brandTeal,
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: index == step
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: reached ? c.brandTeal : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
