import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_password_field.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class OperatorRegistrationPage extends StatefulWidget {
  const OperatorRegistrationPage({super.key});

  @override
  State<OperatorRegistrationPage> createState() =>
      _OperatorRegistrationPageState();
}

class _OperatorRegistrationPageState extends State<OperatorRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _taxController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _companyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OperatorApplicationCubit, OperatorApplicationState>(
      listener: (context, state) {
        if (state.status == OperatorApplicationStatus.pending) {
          context.read<AuthSessionCubit>().previewAs(UserRole.tourOperator);
          context.go(
            AppRoutes.operatorApplication,
            extra: OperatorApplicationStatus.pending,
          );
        }
      },
      builder: (context, state) {
        return AppPageScaffold(
          title: 'Business Account',
          content: [
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                  value: UserRole.traveler,
                  label: Text('Traveler'),
                ),
                ButtonSegment(
                  value: UserRole.tourOperator,
                  label: Text('Tour Operator'),
                ),
              ],
              selected: const {UserRole.tourOperator},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.first == UserRole.traveler) {
                  context.go(AppRoutes.travelerRegistration);
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _companyController,
                    label: 'Company name',
                    validator: (value) => Validators.requiredField(
                      value,
                      fieldName: 'Company name',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _taxController,
                    keyboardType: TextInputType.number,
                    label: 'Tax code',
                    validator: (value) =>
                        Validators.requiredField(value, fieldName: 'Tax code'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DemoLicencePicker(state: state),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    label: 'Business email',
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    label: 'Business phone',
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: _passwordController,
                    label: 'Password',
                    validator: Validators.password,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppAlert(
              message:
                  'Your application is reviewed by an Administrator. You cannot publish tours or receive bookings until it is approved.',
            ),
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: state.isSubmitting ? null : _submit,
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit application'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => context.go(AppRoutes.travelerRegistration),
                child: const Text('Create traveler account instead'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    final cubit = context.read<OperatorApplicationCubit>();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!cubit.state.hasLicence) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the demo licence file first.')),
      );
      return;
    }
    cubit.submit();
  }
}

class _DemoLicencePicker extends StatelessWidget {
  const _DemoLicencePicker({required this.state});

  final OperatorApplicationState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        onTap: context.read<OperatorApplicationCubit>().selectDemoLicence,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.upload_file_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Travel business licence',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(state.licenceFileName ?? 'Tap to select demo file'),
                    const Text(
                      'Mock selection · PDF or JPG, up to 10 MB',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (state.hasLicence)
                const StatusBadge(
                  label: 'Uploaded',
                  type: StatusBadgeType.success,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
