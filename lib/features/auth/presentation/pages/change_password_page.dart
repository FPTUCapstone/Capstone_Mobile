import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/password_demo_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newController.addListener(_refreshStrength);
  }

  @override
  void dispose() {
    _confirmController.dispose();
    _currentController.dispose();
    _newController
      ..removeListener(_refreshStrength)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordDemoCubit, PasswordDemoState>(
      listener: (context, state) {
        if (state.status == PasswordDemoStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: AppSpacing.xs),
                  Text(state.message!),
                ],
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final strength = (_newController.text.length / 12).clamp(0.0, 1.0);
        return AppPageScaffold(
          title: 'Change Password',
          content: [
            const Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('PN')),
                title: Text('Nguyen Minh Phuc'),
                subtitle: Text('Signed in as Traveler'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppPasswordField(
                    controller: _currentController,
                    helperText: 'Demo current password: password123',
                    label: 'Current password',
                    validator: Validators.password,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.lg),
                  AppPasswordField(
                    controller: _newController,
                    label: 'New password',
                    validator: Validators.password,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(20),
                    color: strength > 0.65
                        ? AppColors.success
                        : AppColors.warning,
                    minHeight: 7,
                    value: strength,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Strength: ${strength > 0.65 ? 'Strong' : 'Keep going'}',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _confirmController,
                    label: 'Confirm new password',
                    validator: (value) {
                      if (value != _newController.text) {
                        return 'Passwords do not match.';
                      }
                      return Validators.password(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppAlert(
              message:
                  'Changing your password does not end sessions on other devices. Sign out from devices you no longer use.',
              type: AppAlertType.warning,
            ),
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
                label: 'Update password',
                onPressed: _submit,
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _refreshStrength() => setState(() {});

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<PasswordDemoCubit>().changePassword(
      currentPassword: _currentController.text,
    );
  }
}
