import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_cubit.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';

/// UC-07: self-service change password for the authenticated Traveler or
/// Tour Operator. Confirm New Password is presentation-only and never sent
/// to the Backend. A successful change clears the form and returns to the
/// account/settings page this was pushed from (spec §3/§8); the caller
/// remains on this device, signed in with the replaced session.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listener: (context, state) {
        if (state.status == ChangePasswordStatus.failure &&
            state.fieldErrors.isNotEmpty) {
          _formKey.currentState?.validate();
        }
        if (state.status == ChangePasswordStatus.success) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully.')),
          );
          // Returns to whichever account/settings page pushed this route
          // (Traveler Settings or the Tour Operator Profile tab) — spec §3/§8.
          if (context.canPop()) {
            context.pop();
          }
        }
      },
      builder: (context, state) {
        final busy = state.isSubmitting;
        return AppPageScaffold(
          title: 'Change password',
          content: [
            const SizedBox(height: AppSpacing.md),
            if (state.status == ChangePasswordStatus.success) ...[
              const AppAlert(message: 'Password updated successfully.'),
              const SizedBox(height: AppSpacing.md),
            ],
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppPasswordField(
                    controller: _currentPasswordController,
                    enabled: !busy,
                    label: 'Current password',
                    errorText:
                        state.fieldErrors['currentPassword']?.firstOrNull,
                    onChanged: (_) => context
                        .read<ChangePasswordCubit>()
                        .clearFieldError('currentPassword'),
                    validator: (value) => Validators.requiredField(
                      value,
                      fieldName: 'Current password',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _newPasswordController,
                    enabled: !busy,
                    label: 'New password',
                    helperText:
                        '8–72 characters with uppercase, lowercase, number, and special character.',
                    errorText: state.fieldErrors['newPassword']?.firstOrNull,
                    onChanged: (_) => context
                        .read<ChangePasswordCubit>()
                        .clearFieldError('newPassword'),
                    validator: _validateNewPassword,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _confirmPasswordController,
                    enabled: !busy,
                    label: 'Confirm new password',
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmPassword,
                  ),
                ],
              ),
            ),
            if (state.status == ChangePasswordStatus.failure &&
                state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppAlert(message: state.errorMessage!, type: AppAlertType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Change password',
              isLoading: busy,
              onPressed: busy ? null : _submit,
            ),
          ],
        );
      },
    );
  }

  String? _validateNewPassword(String? value) {
    final policy = Validators.password(value);
    if (policy != null) return policy;
    // Early client-side feedback only; the Backend remains authoritative
    // because it checks the stored hash (UC-07 spec §5).
    if (value == _currentPasswordController.text) {
      return 'New password must be different from the current password.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final required = Validators.requiredField(
      value,
      fieldName: 'Confirm new password',
    );
    if (required != null) return required;
    if (value != _newPasswordController.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    await context.read<ChangePasswordCubit>().submit(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );
  }
}
