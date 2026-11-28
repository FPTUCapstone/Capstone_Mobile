import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _codeFocusNode.addListener(_onFieldVisualChange);
  }

  void _onFieldVisualChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _codeFocusNode
      ..removeListener(_onFieldVisualChange)
      ..dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return BlocConsumer<PasswordRecoveryCubit, PasswordRecoveryState>(
      listener: (context, state) {
        if (state.status == PasswordRecoveryStatus.failure &&
            state.fieldErrors.isNotEmpty) {
          if (state.hasAcceptedRequest) {
            _resetFormKey.currentState?.validate();
          } else {
            _requestFormKey.currentState?.validate();
          }
        }
      },
      builder: (context, state) {
        final isStepTwo = state.hasAcceptedRequest;
        return Theme(
          data: Theme.of(context).copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style: Theme.of(context).filledButtonTheme.style?.copyWith(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? null
                      : palette.primary,
                ),
                foregroundColor: WidgetStatePropertyAll(palette.onPrimary),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: Theme.of(context).textButtonTheme.style?.copyWith(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? null
                      : palette.primary,
                ),
              ),
            ),
          ),
          child: Scaffold(
            backgroundColor: palette.canvas,
            appBar: AppBar(
              toolbarHeight: 40,
              backgroundColor: palette.canvas,
              foregroundColor: palette.ink,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: Navigator.canPop(context) ? 0 : AppSpacing.md,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo/tripmate_emblem_512.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TripMate',
                    style: TextStyle(
                      fontFamily: AppTypography.displayFont,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
            ),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      2,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.border),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryHover.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              isStepTwo
                                  ? 'Đặt lại mật khẩu của bạn'
                                  : 'Quên mật khẩu',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontFamily: AppTypography.displayFont,
                                    fontWeight: FontWeight.w700,
                                    color: palette.ink,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            _RecoveryStepper(
                              currentStep: isStepTwo ? 2 : 1,
                              palette: palette,
                            ),
                            const SizedBox(height: 6),
                            if (isStepTwo)
                              ..._resetContent(context, state, palette)
                            else
                              ..._requestContent(context, state, palette),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _requestContent(
    BuildContext context,
    PasswordRecoveryState state,
    CoastalPalette palette,
  ) {
    final sameEmailCooldown = state.hasActiveCooldownFor(_emailController.text);
    return [
      Text(
        'Nhập địa chỉ email liên kết với tài khoản TripMate của bạn.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: palette.secondary),
      ),
      const SizedBox(height: 12),
      Form(
        key: _requestFormKey,
        child: AppTextField(
          controller: _emailController,
          enabled: !state.isBusy,
          keyboardType: TextInputType.emailAddress,
          label: 'Địa chỉ email',
          prefixIcon: const Icon(Icons.mail_outline),
          textInputAction: TextInputAction.done,
          validator: Validators.email,
          errorText: state.fieldErrors['email']?.firstOrNull,
          onChanged: (value) {
            context.read<PasswordRecoveryCubit>()
              ..clearFieldError('email')
              ..syncEmailCooldown(value);
            setState(() {});
          },
        ),
      ),
      if (sameEmailCooldown) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.softAccent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.primary.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn vừa yêu cầu mã cho email này. Vui lòng đợi '
                '${state.cooldownSeconds} giây để gửi lại.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.primaryHover),
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: state.isBusy
                    ? null
                    : () => context.read<PasswordRecoveryCubit>().resumeReset(
                        _emailController.text,
                      ),
                child: const Text('Nhập mã đã nhận'),
              ),
            ],
          ),
        ),
      ],
      if (state.errorMessage != null) ...[
        const SizedBox(height: 10),
        AppAlert(message: state.errorMessage!, type: AppAlertType.error),
      ],
      const SizedBox(height: 14),
      AppButton(
        label: sameEmailCooldown
            ? 'Gửi mã đặt lại (${state.cooldownSeconds}s)'
            : 'Gửi mã đặt lại',
        isLoading: state.status == PasswordRecoveryStatus.requesting,
        onPressed: state.isBusy || sameEmailCooldown ? null : _submitRequest,
      ),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
          child: const Text('Quay lại đăng nhập'),
        ),
      ),
    ];
  }

  List<Widget> _resetContent(
    BuildContext context,
    PasswordRecoveryState state,
    CoastalPalette palette,
  ) {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final passwordsMatch = password.isNotEmpty && confirm == password;

    return [
      if (state.normalizedEmail != null) ...[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text.rich(
              TextSpan(
                text: 'Mã đã gửi tới ',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.secondary),
                children: [
                  TextSpan(
                    text: state.normalizedEmail,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: state.isBusy
                  ? null
                  : () {
                      _emailController.text = state.normalizedEmail ?? '';
                      context.read<PasswordRecoveryCubit>().editEmail();
                    },
              child: const Text('Đổi email'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Divider(color: palette.border, height: 1),
        ),
      ],
      Form(
        key: _resetFormKey,
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: Theme.of(context).inputDecorationTheme
                .copyWith(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'MÃ ĐẶT LẠI',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.secondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              _OtpSixBoxField(
                controller: _codeController,
                focusNode: _codeFocusNode,
                enabled: !state.isBusy,
                errorText: state.fieldErrors['code']?.firstOrNull,
                palette: palette,
                validator: Validators.otp,
                onChanged: (_) {
                  context.read<PasswordRecoveryCubit>().clearFieldError('code');
                  setState(() {});
                },
              ),
              const SizedBox(height: 6),
              AppPasswordField(
                controller: _passwordController,
                enabled: !state.isBusy,
                label: 'Mật khẩu mới',
                errorText: state.fieldErrors['newPassword']?.firstOrNull,
                onChanged: (_) {
                  context.read<PasswordRecoveryCubit>().clearFieldError(
                    'newPassword',
                  );
                  setState(() {});
                },
                validator: Validators.password,
              ),
              const SizedBox(height: 4),
              _PasswordStrengthChecklist(password: password, palette: palette),
              const SizedBox(height: 6),
              AppPasswordField(
                controller: _confirmPasswordController,
                enabled: !state.isBusy,
                label: 'Xác nhận mật khẩu',
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                validator: _validateConfirmPassword,
              ),
              if (passwordsMatch) ...[
                const SizedBox(height: 2),
                Text(
                  'Mật khẩu khớp',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      if (state.errorMessage != null) ...[
        const SizedBox(height: 6),
        AppAlert(message: state.errorMessage!, type: AppAlertType.error),
      ] else if (state.feedbackMessage != null) ...[
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.softAccent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: palette.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.feedbackMessage!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: palette.primaryHover,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Mã chỉ sử dụng một lần và hết hạn sau 3 phút.',
                  style: TextStyle(fontSize: 10.5, color: palette.secondary),
                ),
              ],
            ),
          ),
        ),
      ] else ...[
        const SizedBox(height: 4),
        Text(
          'Mã chỉ sử dụng một lần và hết hạn sau 3 phút.',
          style: TextStyle(fontSize: 11, color: palette.secondary),
        ),
      ],
      const SizedBox(height: 6),
      AppButton(
        label: 'Đặt lại mật khẩu',
        isLoading: state.status == PasswordRecoveryStatus.confirming,
        onPressed: state.isBusy ? null : _submitReset,
      ),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: state.isBusy || state.cooldownSeconds > 0
                ? null
                : () =>
                      unawaited(context.read<PasswordRecoveryCubit>().resend()),
            child: Text(
              state.cooldownSeconds > 0
                  ? 'Gửi lại mã (${state.cooldownSeconds}s)'
                  : 'Gửi lại mã',
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
            child: const Text('Quay lại đăng nhập'),
          ),
        ],
      ),
    ];
  }

  void _submitRequest() {
    if (_requestFormKey.currentState?.validate() != true) return;
    unawaited(
      context.read<PasswordRecoveryCubit>().requestReset(_emailController.text),
    );
  }

  String? _validateConfirmPassword(String? value) {
    final required = Validators.requiredField(
      value,
      fieldName: 'xác nhận mật khẩu',
    );
    if (required != null) return required;
    if (value != _passwordController.text) {
      return 'Mật khẩu xác nhận không khớp.';
    }
    return null;
  }

  Future<void> _submitReset() async {
    if (_resetFormKey.currentState?.validate() != true) return;
    final cubit = context.read<PasswordRecoveryCubit>();
    final succeeded = await cubit.confirmReset(
      code: _codeController.text,
      newPassword: _passwordController.text,
    );
    if (!mounted || !succeeded) return;
    context.go(AppRoutes.login, extra: cubit.state.feedbackMessage);
  }
}

final class _RecoveryStepper extends StatelessWidget {
  const _RecoveryStepper({required this.currentStep, required this.palette});

  final int currentStep;
  final CoastalPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _step(1, 'Yêu cầu')),
        Expanded(
          child: Container(
            height: 1.5,
            margin: const EdgeInsets.only(top: 11),
            color: currentStep >= 2 ? palette.primary : palette.border,
          ),
        ),
        Expanded(flex: 2, child: _step(2, 'Mật khẩu mới')),
        Expanded(
          child: Container(
            height: 1.5,
            margin: const EdgeInsets.only(top: 11),
            color: currentStep >= 3 ? palette.primary : palette.border,
          ),
        ),
        Expanded(child: _step(3, 'Hoàn tất')),
      ],
    );
  }

  Widget _step(int step, String label) {
    final filled = step <= currentStep;
    final active = step == currentStep;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? palette.primary : palette.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? palette.primary : palette.border,
            ),
          ),
          child: Text(
            '$step',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: filled ? palette.onPrimary : palette.secondary,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? palette.ink : palette.secondary,
          ),
        ),
      ],
    );
  }
}

/// Visual 6-box OTP entry backed by a single real [TextFormField] so paste,
/// SMS autofill, backspace, validation, and form tests work seamlessly.
final class _OtpSixBoxField extends StatelessWidget {
  const _OtpSixBoxField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.palette,
    required this.validator,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? errorText;
  final CoastalPalette palette;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = controller.text;
    final chars = value.runes.map(String.fromCharCode).toList(growable: false);
    final activeIndex = chars.length.clamp(0, 5);
    final hasFocus = focusNode.hasFocus;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        IgnorePointer(
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                Expanded(
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: enabled ? palette.surface : palette.canvas,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasFocus && i == activeIndex
                            ? palette.primary
                            : palette.border,
                        width: hasFocus && i == activeIndex ? 1.6 : 1.1,
                      ),
                    ),
                    child: Text(
                      i < chars.length ? chars[i] : '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ),
                if (i < 5) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [LengthLimitingTextInputFormatter(6)],
          showCursor: false,
          enableInteractiveSelection: true,
          style: const TextStyle(color: Colors.transparent, fontSize: 15),
          cursorColor: Colors.transparent,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: false,
            isDense: true,
            labelText: 'Mã đặt lại',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
            floatingLabelStyle: const TextStyle(
              color: Colors.transparent,
              fontSize: 1,
            ),
            errorText: errorText,
            errorMaxLines: 2,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
      ],
    );
  }
}

final class _PasswordStrengthChecklist extends StatelessWidget {
  const _PasswordStrengthChecklist({
    required this.password,
    required this.palette,
  });

  final String password;
  final CoastalPalette palette;

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8 && password.length <= 72;
    final hasCase =
        RegExp('[A-Z]').hasMatch(password) &&
        RegExp('[a-z]').hasMatch(password);
    final hasNumber = RegExp('[0-9]').hasMatch(password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    final score = [
      hasLength,
      hasCase,
      hasNumber,
      hasSymbol,
    ].where((met) => met).length;

    final barColor = switch (score) {
      >= 4 => palette.success,
      3 => palette.primary,
      2 => palette.warningText,
      _ => palette.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: i < score ? barColor : palette.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (i < 3) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 2,
          children: [
            _ruleDot(context, 'Từ 8 ký tự', hasLength),
            _ruleDot(context, 'Chữ hoa & thường', hasCase),
            _ruleDot(context, '1 chữ số', hasNumber),
            _ruleDot(context, '1 ký tự đặc biệt', hasSymbol),
          ],
        ),
      ],
    );
  }

  Widget _ruleDot(BuildContext context, String label, bool met) {
    final color = met ? palette.success : palette.secondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5.5,
          height: 5.5,
          decoration: BoxDecoration(
            color: met ? palette.success : palette.border,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10.5,
            color: color,
            fontWeight: met ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
