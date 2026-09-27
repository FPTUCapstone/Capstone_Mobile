import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        return AppPageScaffold(
          title: state.hasAcceptedRequest
              ? 'Reset your password'
              : 'Forgot password',
          content: state.hasAcceptedRequest
              ? _resetContent(context, state)
              : _requestContent(context, state),
        );
      },
    );
  }

  List<Widget> _requestContent(
    BuildContext context,
    PasswordRecoveryState state,
  ) => [
    const SizedBox(height: AppSpacing.md),
    Text(
      'Enter the email address associated with your TripMate account.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: AppSpacing.lg),
    Form(
      key: _requestFormKey,
      child: AppTextField(
        controller: _emailController,
        enabled: !state.isBusy,
        keyboardType: TextInputType.emailAddress,
        label: 'Email address',
        prefixIcon: const Icon(Icons.mail_outline),
        textInputAction: TextInputAction.done,
        validator: Validators.email,
        errorText: state.fieldErrors['email']?.firstOrNull,
        onChanged: (_) =>
            context.read<PasswordRecoveryCubit>().clearFieldError('email'),
      ),
    ),
    if (state.errorMessage != null) ...[
      const SizedBox(height: AppSpacing.md),
      AppAlert(message: state.errorMessage!, type: AppAlertType.error),
    ],
    const SizedBox(height: AppSpacing.lg),
    AppButton(
      label: 'Send Reset Code',
      isLoading: state.status == PasswordRecoveryStatus.requesting,
      onPressed: state.isBusy ? null : _submitRequest,
    ),
    const SizedBox(height: AppSpacing.sm),
    TextButton(
      onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
      child: const Text('Back to sign in'),
    ),
  ];

  List<Widget> _resetContent(
    BuildContext context,
    PasswordRecoveryState state,
  ) => [
    const SizedBox(height: AppSpacing.md),
    if (state.feedbackMessage != null)
      AppAlert(message: state.feedbackMessage!),
    const SizedBox(height: AppSpacing.md),
    const Text('The code is single-use and expires in 3 minutes.'),
    const SizedBox(height: AppSpacing.lg),
    Form(
      key: _resetFormKey,
      child: Column(
        children: [
          AppTextField(
            controller: _codeController,
            enabled: !state.isBusy,
            keyboardType: TextInputType.number,
            label: 'Reset code',
            errorText: state.fieldErrors['code']?.firstOrNull,
            onChanged: (_) =>
                context.read<PasswordRecoveryCubit>().clearFieldError('code'),
            validator: Validators.otp,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            controller: _passwordController,
            enabled: !state.isBusy,
            label: 'New password',
            errorText: state.fieldErrors['newPassword']?.firstOrNull,
            onChanged: (_) => context
                .read<PasswordRecoveryCubit>()
                .clearFieldError('newPassword'),
            helperText:
                '8–72 characters with uppercase, lowercase, number, and special character.',
            validator: Validators.password,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            controller: _confirmPasswordController,
            enabled: !state.isBusy,
            label: 'Confirm password',
            textInputAction: TextInputAction.done,
            validator: _validateConfirmPassword,
          ),
        ],
      ),
    ),
    if (state.errorMessage != null) ...[
      const SizedBox(height: AppSpacing.md),
      AppAlert(message: state.errorMessage!, type: AppAlertType.error),
    ],
    const SizedBox(height: AppSpacing.lg),
    AppButton(
      label: 'Reset Password',
      isLoading: state.status == PasswordRecoveryStatus.confirming,
      onPressed: state.isBusy ? null : _submitReset,
    ),
    const SizedBox(height: AppSpacing.sm),
    TextButton(
      onPressed: state.isBusy || state.cooldownSeconds > 0
          ? null
          : () => unawaited(context.read<PasswordRecoveryCubit>().resend()),
      child: Text(
        state.cooldownSeconds > 0
            ? 'Resend code (${state.cooldownSeconds}s)'
            : 'Resend code',
      ),
    ),
    TextButton(
      onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
      child: const Text('Back to sign in'),
    ),
  ];

  void _submitRequest() {
    if (_requestFormKey.currentState?.validate() != true) return;
    unawaited(
      context.read<PasswordRecoveryCubit>().requestReset(_emailController.text),
    );
  }

  String? _validateConfirmPassword(String? value) {
    final required = Validators.requiredField(
      value,
      fieldName: 'Confirm password',
    );
    if (required != null) return required;
    if (value != _passwordController.text) return 'Passwords do not match.';
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
