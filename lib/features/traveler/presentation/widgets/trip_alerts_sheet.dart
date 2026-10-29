import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';

class TripAlertsSheet extends StatelessWidget {
  const TripAlertsSheet({
    super.key,
    required this.alerts,
    this.onReviewReroute,
    this.onOpenAlert,
    this.onConfirmArrival,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final List<TripAlert> alerts;
  final VoidCallback? onReviewReroute;
  final ValueChanged<TripAlert>? onOpenAlert;
  final ValueChanged<TripAlert>? onConfirmArrival;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  static Future<void> show(
    BuildContext context, {
    required ActiveTripCubit cubit,
    String? firstAlertId,
    ValueChanged<TripAlert>? onOpenAlert,
    ValueChanged<TripAlert>? onConfirmArrival,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocBuilder<ActiveTripCubit, ActiveTripState>(
        bloc: cubit,
        builder: (_, state) {
          final alerts = firstAlertId == null
              ? state.alerts
              : [
                  ...state.alerts.where((alert) => alert.id == firstAlertId),
                  ...state.alerts.where((alert) => alert.id != firstAlertId),
                ];
          return TripAlertsSheet(
            alerts: alerts,
            onReviewReroute: state.activeRerouteProposal == null
                ? null
                : cubit.openRerouteProposal,
            onOpenAlert: onOpenAlert,
            onConfirmArrival: onConfirmArrival,
            isLoading: state.alertRefreshStatus == AlertRefreshStatus.loading,
            errorMessage: state.alertRefreshError,
            onRetry: cubit.refreshAlerts,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Trip Alerts',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${alerts.length}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (isLoading) const LinearProgressIndicator(minHeight: 2),
            if (errorMessage != null)
              MaterialBanner(
                content: Text(errorMessage!),
                actions: [
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),

            // List of alerts
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 48,
                            color: AppColors.success,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'No alerts for this trip',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          const Text(
                            'All routes and stops are operating normally.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: alerts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        return _AlertListCard(
                          alert: alerts[index],
                          onOpen: onOpenAlert == null
                              ? null
                              : () => onOpenAlert?.call(alerts[index]),
                          onConfirmArrival: onConfirmArrival == null
                              ? null
                              : () => onConfirmArrival?.call(alerts[index]),
                          onReviewReroute: onReviewReroute == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  onReviewReroute?.call();
                                },
                        );
                      },
                    ),
            ),

            // Footer note
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                'Alerts are retained for the duration of the active trip.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertListCard extends StatelessWidget {
  const _AlertListCard({
    required this.alert,
    this.onReviewReroute,
    this.onOpen,
    this.onConfirmArrival,
  });

  final TripAlert alert;
  final VoidCallback? onReviewReroute;
  final VoidCallback? onOpen;
  final VoidCallback? onConfirmArrival;

  @override
  Widget build(BuildContext context) {
    final (borderColor, icon, severityLabel) = switch (alert.severity) {
      AlertSeverity.critical => (
        AppColors.error,
        Icons.warning_amber_rounded,
        'CRITICAL',
      ),
      AlertSeverity.warning => (
        AppColors.warning,
        Icons.schedule_rounded,
        'WARNING',
      ),
      AlertSeverity.info => (
        AppColors.primary,
        Icons.info_outline_rounded,
        'NOTICE',
      ),
    };

    final timeStr =
        '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}';

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border(left: BorderSide(color: borderColor, width: 4)),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: borderColor, size: 16),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    severityLabel,
                    style: TextStyle(
                      color: borderColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (alert.isRead) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.done_all,
                      size: 15,
                      color: AppColors.muted,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                alert.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                alert.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink,
                  height: 1.3,
                ),
              ),
              if (alert.isResolved) ...[
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Resolved',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      alert.affectedStopName,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (alert.type == TripAlertType.delay &&
                  onConfirmArrival != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onConfirmArrival,
                    child: const Text("Confirm I've arrived"),
                  ),
                ),
              ],
              if (alert.rerouteProposalAvailable &&
                  onReviewReroute != null) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReviewReroute,
                    icon: const Icon(Icons.alt_route_rounded, size: 16),
                    label: const Text('Review Re-routing Proposal'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
