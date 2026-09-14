import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class TravelerRegistrationPage extends StatelessWidget {
  const TravelerRegistrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RegisterCubit>(
      create: (_) => serviceLocator<RegisterCubit>(),
      child: const _TravelerRegistrationForm(),
    );
  }
}

class _TravelerRegistrationForm extends StatefulWidget {
  const _TravelerRegistrationForm();

  @override
  State<_TravelerRegistrationForm> createState() =>
      __TravelerRegistrationFormState();
}

class __TravelerRegistrationFormState extends State<_TravelerRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _acceptedTerms = false;

  @override
  void dispose() {
    _confirmController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterCubit, RegisterState>(
      listener: (context, state) async {
        if (state is RegisterSuccess) {
          final response = state.response;
          if (response.status != 'PendingEmailVerification') {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Registration response status is unrecognized. Please contact support.',
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Registration successful. Please verify your email before signing in.',
              ),
            ),
          );
          context.go(AppRoutes.verifyEmail, extra: response.email);
        } else if (state is RegisterFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is RegisterLoading;

        return AppPageScaffold(
          title: 'Create Account',
          content: [
            Text(
              'Join TripMate to plan one-day itineraries around your own time, budget and pace.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _nameController,
                    label: 'Full name',
                    textInputAction: TextInputAction.next,
                    enabled: !isSubmitting,
                    validator: Validators.fullName,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    label: 'Email address',
                    textInputAction: TextInputAction.next,
                    enabled: !isSubmitting,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    label: 'Phone number',
                    textInputAction: TextInputAction.next,
                    enabled: !isSubmitting,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _passwordController,
                    helperText:
                        'Use upper case, lower case, a number and a special character.',
                    label: 'Password',
                    textInputAction: TextInputAction.next,
                    enabled: !isSubmitting,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _confirmController,
                    label: 'Confirm password',
                    enabled: !isSubmitting,
                    validator: (value) {
                      final requiredError = Validators.requiredField(
                        value,
                        fieldName: 'Confirm password',
                      );
                      if (requiredError != null) {
                        return requiredError;
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match. Please re-enter.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acceptedTerms,
              onChanged: isSubmitting
                  ? null
                  : (value) => setState(() => _acceptedTerms = value ?? false),
              title: const Text(
                'I agree to the Terms of Service and the Privacy Policy.',
              ),
            ),
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                isLoading: isSubmitting,
                label: 'Register',
                onPressed: _acceptedTerms && !isSubmitting ? _register : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => context.go(AppRoutes.login),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _register() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<RegisterCubit>().registerTraveler(
      fullName: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      confirmPassword: _confirmController.text,
      acceptedTerms: _acceptedTerms,
    );
  }
}
