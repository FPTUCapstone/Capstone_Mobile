import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/tripmate_visual_tokens.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/widgets/operator_review_process.dart';
import 'package:trip_mate_mobile/shared/widgets/anchored_action_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/section_card.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// UC-03 Operator Application Status (Screen #41).
///
/// The status shown here is the Backend-issued application status carried by
/// the authenticated session (`AuthSessionCubit`). No application code, dates,
/// company, document or rejection-reason data exists on Mobile yet, so the
/// designed regions show that the data is not available, and no resubmission
/// can be started or simulated. Routing of approved operators is owned by
/// `RouteGuards`.
class OperatorApplicationPage extends StatelessWidget {
  const OperatorApplicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (AuthSessionCubit cubit) => cubit.state.applicationStatus,
    );

    return TripMateVisualTheme(
      child: Scaffold(
        appBar: AppBar(title: const Text('My Application')),
        bottomNavigationBar: status == TourOperatorApplicationStatus.rejected
            ? const AnchoredActionBar(
                child: CapabilityNote(
                  message:
                      'Resubmission is not available in the mobile app yet.',
                ),
              )
            : null,
        body: AppPageScaffold(
          showAppBar: false,
          content: switch (status) {
            TourOperatorApplicationStatus.pendingApproval => const [
              _PendingApplicationView(),
            ],
            TourOperatorApplicationStatus.rejected => const [
              _RejectedApplicationView(),
            ],
            TourOperatorApplicationStatus.approved => const [
              _ApprovedApplicationView(),
            ],
            TourOperatorApplicationStatus.unresolved => const [
              AppAlert(
                title: 'Application status unavailable',
                message:
                    'We could not confirm your application status. Please '
                    'contact TripMate support.',
                type: AppAlertType.warning,
              ),
            ],
          },
        ),
      ),
    );
  }
}

class _PendingApplicationView extends StatelessWidget {
  const _PendingApplicationView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ApplicationSummaryCard(
          icon: Icons.hourglass_top_rounded,
          badgeLabel: 'Pending approval',
          badgeType: StatusBadgeType.warning,
        ),
        SizedBox(height: AppSpacing.md),
        _StatusMessage(
          tone: _MessageTone.info,
          icon: Icons.info_outline,
          title: 'Awaiting Administrator review',
          message:
              'Your application is awaiting Administrator review. Tour '
              'publishing and bookings stay unavailable until it is approved.',
        ),
        SizedBox(height: AppSpacing.md),
        _UnavailableRegion(
          icon: Icons.folder_open_outlined,
          title: 'Attached documents',
          message: "Your documents aren't available in the app.",
        ),
        SizedBox(height: AppSpacing.md),
        _UnavailableRegion(
          icon: Icons.assignment_outlined,
          title: 'Declared information',
          message: "Your declared details aren't available in the app.",
        ),
        SizedBox(height: AppSpacing.md),
        // The session status says the application is under review.
        OperatorReviewProcess(currentStep: 1),
      ],
    );
  }
}

class _RejectedApplicationView extends StatelessWidget {
  const _RejectedApplicationView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ApplicationSummaryCard(
          icon: Icons.cancel_outlined,
          badgeLabel: 'Rejected',
          badgeType: StatusBadgeType.error,
        ),
        SizedBox(height: AppSpacing.md),
        _StatusMessage(
          tone: _MessageTone.error,
          icon: Icons.error_outline,
          title: 'Rejection reason',
          message: 'Reason unavailable in the app.',
          footnote:
              'Tour publishing and bookings stay unavailable while the '
              'application is rejected.',
        ),
        SizedBox(height: AppSpacing.md),
        _UnavailableRegion(
          icon: Icons.folder_open_outlined,
          title: 'Attached documents',
          message: "Your documents aren't available in the app.",
        ),
        SizedBox(height: AppSpacing.md),
        _UnavailableRegion(
          icon: Icons.assignment_outlined,
          title: 'Declared information',
          message: "Your declared details aren't available in the app.",
        ),
      ],
    );
  }
}

class _ApprovedApplicationView extends StatelessWidget {
  const _ApprovedApplicationView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ApplicationSummaryCard(
          icon: Icons.check_circle_outline,
          badgeLabel: 'Approved',
          badgeType: StatusBadgeType.success,
        ),
        SizedBox(height: AppSpacing.md),
        _StatusMessage(
          tone: _MessageTone.info,
          icon: Icons.info_outline,
          title: 'Application approved',
          message: 'Your application has been approved.',
        ),
      ],
    );
  }
}

/// The Stitch application summary card: status pill and the application
/// reference fields. Only the status is authoritative on Mobile; the other
/// fields have no source yet and say so.
class _ApplicationSummaryCard extends StatelessWidget {
  const _ApplicationSummaryCard({
    required this.icon,
    required this.badgeLabel,
    required this.badgeType,
  });

  final String badgeLabel;
  final StatusBadgeType badgeType;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = switch (badgeType) {
      StatusBadgeType.error => scheme.error,
      StatusBadgeType.success => scheme.primary,
      _ => TripMateVisualTokens.navy,
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Application status',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: StatusBadge(label: badgeLabel, type: badgeType),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
          const _ReferenceRow(label: 'Application code'),
          const SizedBox(height: AppSpacing.xs),
          const _ReferenceRow(label: 'Submission date'),
          const SizedBox(height: AppSpacing.xs),
          const _ReferenceRow(label: 'Review date'),
        ],
      ),
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          'Not available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

enum _MessageTone { info, error }

/// The tinted status-message region (Stitch's rejection-reason box).
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    this.footnote,
  });

  final String? footnote;
  final IconData icon;
  final String message;
  final String title;
  final _MessageTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, border, accent) = switch (tone) {
      _MessageTone.error => (
        TripMateVisualTokens.coralLight,
        TripMateVisualTokens.coralBorder,
        scheme.error,
      ),
      _MessageTone.info => (
        scheme.primaryContainer,
        scheme.primary.withValues(alpha: 0.25),
        scheme.primary,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TripMateVisualTokens.cardRadius),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (footnote != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      footnote!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A designed Stitch region whose data has no source on Mobile yet.
class _UnavailableRegion extends StatelessWidget {
  const _UnavailableRegion({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String message;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.secondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              IconTile(icon: icon, muted: true),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
