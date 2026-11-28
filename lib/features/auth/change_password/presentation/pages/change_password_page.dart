import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_cubit.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_state.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_section_card.dart';

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
            const SnackBar(content: Text('Đổi mật khẩu thành công.')),
          );
          // Returns to whichever account/settings page pushed this route
          // (Traveler Settings or the Tour Operator Profile tab) — spec §3/§8.
          // A direct/deep-link open of this route has no back stack to pop:
          // fall back to the role-appropriate settings/profile destination so
          // the user is never stranded on the Change Password screen.
          if (context.canPop()) {
            context.pop();
          } else {
            final role = context.read<AuthSessionCubit>().state.role;
            context.go(
              role == UserRole.tourOperator
                  ? AppRoutes.operator
                  : AppRoutes.travelerSettings,
            );
          }
        }
      },
      builder: (context, state) {
        final busy = state.isSubmitting;
        return AppPageScaffold(
          title: 'Đổi mật khẩu',
          content: [
            if (state.status == ChangePasswordStatus.success) ...[
              const AppAlert(
                type: AppAlertType.success,
                message: 'Đổi mật khẩu thành công.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppSectionCard(
              title: 'Thông tin bảo mật',
              subtitle:
                  'Chọn mật khẩu mạnh để bảo vệ tài khoản TripMate của bạn.',
              icon: Icons.lock_outline_rounded,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppPasswordField(
                      controller: _currentPasswordController,
                      enabled: !busy,
                      label: 'Mật khẩu hiện tại',
                      errorText:
                          state.fieldErrors['currentPassword']?.firstOrNull,
                      onChanged: (_) => context
                          .read<ChangePasswordCubit>()
                          .clearFieldError('currentPassword'),
                      validator: (value) => Validators.requiredField(
                        value,
                        fieldName: 'mật khẩu hiện tại',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppPasswordField(
                      controller: _newPasswordController,
                      enabled: !busy,
                      label: 'Mật khẩu mới',
                      helperText:
                          '8–72 ký tự gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt.',
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
                      label: 'Xác nhận mật khẩu mới',
                      textInputAction: TextInputAction.done,
                      validator: _validateConfirmPassword,
                    ),
                  ],
                ),
              ),
            ),
            if (state.status == ChangePasswordStatus.failure &&
                state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppAlert(message: state.errorMessage!, type: AppAlertType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Đổi mật khẩu',
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
      return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final required = Validators.requiredField(
      value,
      fieldName: 'xác nhận mật khẩu mới',
    );
    if (required != null) return required;
    if (value != _newPasswordController.text) {
      return 'Mật khẩu xác nhận không khớp.';
    }
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
