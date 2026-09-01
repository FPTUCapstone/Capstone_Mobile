import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/app_text_field.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class OperatorApplicationPage extends StatefulWidget {
  const OperatorApplicationPage({super.key});

  @override
  State<OperatorApplicationPage> createState() =>
      _OperatorApplicationPageState();
}

class _OperatorApplicationPageState extends State<OperatorApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController(
    text: '02 Nguyen Van Linh, Da Nang',
  );
  final _phoneController = TextEditingController(text: '0236 388 1234');

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OperatorApplicationCubit, OperatorApplicationState>(
      builder: (context, state) {
        if (state.status == OperatorApplicationStatus.pending) {
          return const _PendingApplicationView();
        }
        return AppPageScaffold(
          title: 'My Application',
          content: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.business_outlined)),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Han River Travel Co., Ltd',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('Tax code 0401998877'),
                        ],
                      ),
                    ),
                    const StatusBadge(
                      label: 'Rejected',
                      type: StatusBadgeType.error,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppAlert(
              title: 'Rejection reason',
              message:
                  'The uploaded travel business licence is expired. Please upload a valid licence and correct the company address.',
              type: AppAlertType.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'CORRECT THE FOLLOWING',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _addressController,
                    label: 'Company address',
                    validator: (value) => Validators.requiredField(
                      value,
                      fieldName: 'Company address',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Travel business licence',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  state.licenceFileName ??
                                      'licence-2026-renewed.pdf',
                                ),
                                const Text(
                                  'Previous file expired 30/06/2026',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const StatusBadge(
                            label: 'Replaced',
                            type: StatusBadgeType.success,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    label: 'Business phone',
                    validator: Validators.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppAlert(
              message:
                  'After resubmission the application returns to Pending Approval. Existing demo sign-in details stay unchanged.',
            ),
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                isLoading: state.isSubmitting,
                label: 'Resubmit application',
                onPressed: _resubmit,
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Support contact is visual only in this demo.',
                    ),
                  ),
                ),
                child: const Text('Contact TripMate support'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<OperatorApplicationCubit>().submit(isResubmission: true);
  }
}

class _PendingApplicationView extends StatelessWidget {
  const _PendingApplicationView();

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'My Application',
      content: [
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Center(
          child: StatusBadge(
            label: 'Pending Approval',
            type: StatusBadgeType.warning,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Application submitted',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'TripMate will review the demo application. Tour publishing and bookings remain unavailable until approval.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppAlert(
          message:
              'This Pending Approval state is simulated locally. No document or company data was uploaded.',
          type: AppAlertType.warning,
        ),
      ],
    );
  }
}
