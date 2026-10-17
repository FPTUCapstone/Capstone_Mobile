import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class OperatorApplicationPage extends StatefulWidget {
  const OperatorApplicationPage({super.key});
  @override
  State<OperatorApplicationPage> createState() =>
      _OperatorApplicationPageState();
}

class _OperatorApplicationPageState extends State<OperatorApplicationPage> {
  @override
  void initState() {
    super.initState();
    context.read<OperatorApplicationCubit>().loadApplication();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<OperatorApplicationCubit, OperatorApplicationState>(
    builder: (context, state) {
      if (state.status == OperatorApplicationStatus.loading) {
        return const AppPageScaffold(
          title: 'My Application',
          content: [Center(child: CircularProgressIndicator())],
        );
      }
      if (state.status == OperatorApplicationStatus.unresolved ||
          state.application == null) {
        return AppPageScaffold(
          title: 'My Application',
          content: [
            AppAlert(
              title: 'Application status unavailable',
              message: state.errorMessage ?? 'Unable to load the application.',
              type: AppAlertType.error,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Retry',
              onPressed: context
                  .read<OperatorApplicationCubit>()
                  .loadApplication,
            ),
          ],
          footer: const _SignOutButton(),
        );
      }
      final application = state.application!;
      final rejected = state.status == OperatorApplicationStatus.rejected;
      final pending = state.status == OperatorApplicationStatus.pending;
      return AppPageScaffold(
        title: 'My Application',
        content: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          application.companyName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      StatusBadge(
                        label: pending
                            ? 'Pending Approval'
                            : application.approvalStatus,
                        type: rejected
                            ? StatusBadgeType.error
                            : pending
                            ? StatusBadgeType.warning
                            : StatusBadgeType.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Tax code ${application.taxCode}'),
                  Text('Resubmissions: ${application.resubmissionCount}'),
                ],
              ),
            ),
          ),
          if (rejected) ...[
            const SizedBox(height: AppSpacing.md),
            AppAlert(
              title: 'Rejection reason',
              message: application.rejectionReason ?? 'No reason recorded.',
              type: AppAlertType.error,
            ),
          ],
          if (pending) ...[
            const SizedBox(height: AppSpacing.md),
            const AppAlert(
              message:
                  'Your application is pending administrator review. Tour publishing and bookings remain unavailable.',
            ),
          ],
          if (state.status == OperatorApplicationStatus.approved) ...[
            const SizedBox(height: AppSpacing.md),
            const AppAlert(
              message: 'Your Tour Operator application is approved.',
              type: AppAlertType.success,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('DOCUMENTS', style: Theme.of(context).textTheme.labelSmall),
          ...application.documents.map(
            (document) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text('${document.documentType} #${document.documentId}'),
              subtitle: Text(document.status),
            ),
          ),
          if (state.successMessage != null)
            AppAlert(
              message: state.successMessage!,
              type: AppAlertType.success,
            ),
        ],
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rejected)
              AppButton(
                label: 'Resubmit application',
                onPressed: () =>
                    context.push(AppRoutes.operatorApplicationResubmit),
              ),
            const SizedBox(height: AppSpacing.sm),
            const _SignOutButton(),
          ],
        ),
      );
    },
  );
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => context.read<AuthSessionCubit>().signOut(),
    icon: const Icon(Icons.logout),
    label: const Text('Sign out'),
  );
}
