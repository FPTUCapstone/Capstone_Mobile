import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_email_recovery_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class OperatorEmailRecoveryPage extends StatefulWidget {
  const OperatorEmailRecoveryPage({this.email, super.key});

  final String? email;

  @override
  State<OperatorEmailRecoveryPage> createState() =>
      _OperatorEmailRecoveryPageState();
}

class _OperatorEmailRecoveryPageState extends State<OperatorEmailRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.email);
  final _passwordController = TextEditingController();
  Timer? _cooldownTimer;
  var _cooldownSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  void _submit({required bool send}) {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<OperatorEmailRecoveryCubit>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (send) {
      cubit.sendEmail(email: email, password: password);
    } else {
      cubit.checkEmail(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OperatorEmailRecoveryCubit, OperatorEmailRecoveryState>(
      listenWhen: (previous, current) =>
          previous.phase != OperatorEmailRecoveryPhase.sent &&
          current.phase == OperatorEmailRecoveryPhase.sent,
      listener: (_, _) => _startCooldown(),
      builder: (context, state) => AppPageScaffold(
        title: 'Continue email verification',
        content: [
          const Center(child: Icon(Icons.mark_email_read_outlined, size: 64)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Finish email verification',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'If you already submitted your Tour Operator application, enter the same email and password. '
            'Open the link in your inbox, then return here to confirm your email.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppAlert(
            message:
                'Verifying your email does not approve the application. '
                'It remains Pending Approval until an administrator reviews it.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: _emailController,
                  label: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      Validators.requiredField(value, fieldName: 'Password'),
                ),
              ],
            ),
          ),
          if (state.message != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppAlert(
              message: state.message!,
              type: switch (state.phase) {
                OperatorEmailRecoveryPhase.verified => AppAlertType.success,
                OperatorEmailRecoveryPhase.error => AppAlertType.error,
                _ => AppAlertType.info,
              },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed:
                state.isBusy ||
                    state.phase == OperatorEmailRecoveryPhase.verified ||
                    _cooldownSeconds > 0
                ? null
                : () => _submit(send: true),
            child: Text(
              _cooldownSeconds > 0
                  ? 'Resend in ${_cooldownSeconds}s'
                  : 'Send verification email',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed:
                state.isBusy ||
                    state.phase == OperatorEmailRecoveryPhase.verified
                ? null
                : () => _submit(send: false),
            child: const Text("I've verified my email"),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: state.isBusy ? null : () => context.go(AppRoutes.login),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
