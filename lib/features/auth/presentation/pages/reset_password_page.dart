import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/password_demo_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_refreshPolicy);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _confirmController.dispose();
    _passwordController
      ..removeListener(_refreshPolicy)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordDemoCubit, PasswordDemoState>(
      listener: (context, state) async {
        if (state.status == PasswordDemoStatus.success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message!)));
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (context.mounted) {
            context.go(AppRoutes.login);
          }
        }
      },
      builder: (context, state) {
        return AppPageScaffold(
          title: 'Reset Password',
          content: [
            const AppAlert(
              message:
                  'We sent a 6-digit demo code to traveler@tripmate.demo. The code expires in 05:00.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _codeController,
                    helperText: 'Demo code: 123456 · expires in 04:12',
                    keyboardType: TextInputType.number,
                    label: 'Verification code',
                    prefixIcon: const Icon(Icons.password_outlined),
                    validator: (value) => Validators.requiredField(
                      value,
                      fieldName: 'Verification code',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resendCode,
                      child: const Text('Resend code'),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _passwordController,
                    label: 'New password',
                    validator: Validators.password,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _confirmController,
                    label: 'Confirm new password',
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match.';
                      }
                      return Validators.password(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PasswordPolicyCard(password: _passwordController.text),
            if (state.status == PasswordDemoStatus.failure) ...[
              const SizedBox(height: AppSpacing.md),
              AppAlert(message: state.message!, type: AppAlertType.error),
            ],
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                isLoading: state.isLoading,
                label: 'Set new password',
                onPressed: _submit,
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Phone recovery is visual only in this demo.',
                    ),
                  ),
                ),
                child: const Text('Use phone number instead'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _refreshPolicy() => setState(() {});

  void _resendCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new demo code was generated: 123456')),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<PasswordDemoCubit>().resetPassword(
      code: _codeController.text,
      password: _passwordController.text,
    );
  }
}

class _PasswordPolicyCard extends StatelessWidget {
  const _PasswordPolicyCard({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8;
    final hasCases =
        password.contains(RegExp('[A-Z]')) &&
        password.contains(RegExp('[a-z]'));
    final hasNumberAndSymbol =
        password.contains(RegExp('[0-9]')) &&
        password.contains(RegExp(r'[^A-Za-z0-9]'));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PASSWORD MUST CONTAIN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PolicyRow(label: 'At least 8 characters', met: hasLength),
            _PolicyRow(label: 'Upper and lower case letters', met: hasCases),
            _PolicyRow(
              label: 'A number and a special character',
              met: hasNumberAndSymbol,
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check : Icons.circle_outlined,
            color: met ? AppColors.success : AppColors.muted,
            size: 17,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(label)),
          StatusBadge(
            label: met ? 'Met' : 'Pending',
            type: met ? StatusBadgeType.success : StatusBadgeType.neutral,
          ),
        ],
      ),
    );
  }
}
