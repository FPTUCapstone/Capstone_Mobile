import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';

class TravelerRegistrationPage extends StatefulWidget {
  const TravelerRegistrationPage({super.key});

  @override
  State<TravelerRegistrationPage> createState() =>
      _TravelerRegistrationPageState();
}

class _TravelerRegistrationPageState extends State<TravelerRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _acceptedTerms = false;
  var _isSubmitting = false;

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
                validator: (value) =>
                    Validators.requiredField(value, fieldName: 'Full name'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                label: 'Email address',
                textInputAction: TextInputAction.next,
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                label: 'Phone number',
                textInputAction: TextInputAction.next,
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AppPasswordField(
                controller: _passwordController,
                helperText:
                    'Use upper case, lower case, a number and a special character.',
                label: 'Password',
                textInputAction: TextInputAction.next,
                validator: Validators.password,
              ),
              const SizedBox(height: AppSpacing.md),
              AppPasswordField(
                controller: _confirmController,
                label: 'Confirm password',
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
          onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('I agree to the '),
              _PolicyLink(label: 'Terms of Service', onTap: _showPolicyDemo),
              const Text(' and the '),
              _PolicyLink(label: 'Privacy Policy', onTap: _showPolicyDemo),
              const Text('.'),
            ],
          ),
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            isLoading: _isSubmitting,
            label: 'Register',
            onPressed: _acceptedTerms ? _register : null,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Already have an account?'),
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Traveler demo account created successfully.'),
      ),
    );
    context.go(AppRoutes.login);
  }

  void _showPolicyDemo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Policy link is visual only in this demo.')),
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
