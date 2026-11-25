import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
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
    this.onDepartStop,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final List<TripAlert> alerts;
  final ValueChanged<TripAlert>? onReviewReroute;
  final ValueChanged<TripAlert>? onOpenAlert;
  final ValueChanged<TripAlert>? onConfirmArrival;
  final ValueChanged<TripAlert>? onDepartStop;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  static Future<void> show(
    BuildContext context, {
    required ActiveTripCubit cubit,
    String? firstAlertId,
    ValueChanged<TripAlert>? onOpenAlert,
    ValueChanged<TripAlert>? onConfirmArrival,
    ValueChanged<TripAlert>? onDepartStop,
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
            onReviewReroute: (alert) =>
                unawaited(cubit.openRerouteProposal(alert)),
            onOpenAlert: onOpenAlert,
            onConfirmArrival: onConfirmArrival,
            onDepartStop: state.session?.isExploring == true
                ? onDepartStop
                : null,
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
    final palette = CoastalPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Cảnh báo chuyến đi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: palette.ink,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: palette.softAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${alerts.length}',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: palette.ink),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            if (isLoading)
              LinearProgressIndicator(minHeight: 2, color: palette.primary),
            if (errorMessage != null)
              MaterialBanner(
                backgroundColor: palette.errorBg,
                content: Text(
                  errorMessage!,
                  style: TextStyle(color: palette.ink),
                ),
                actions: [
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Thử lại'),
                    ),
                ],
              ),
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: palette.softAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                size: 36,
                                color: palette.success,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Chưa có cảnh báo nào',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: palette.ink,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Tất cả tuyến đường và điểm dừng đều đang ổn định.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.secondary),
                            ),
                          ],
                        ),
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
                          onDepartStop: onDepartStop == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  onDepartStop?.call(alerts[index]);
                                },
                          onReviewReroute: onReviewReroute == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  onReviewReroute?.call(alerts[index]);
                                },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                'Cảnh báo được lưu lại trong suốt thời gian chuyến đi diễn ra.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.secondary,
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
    this.onDepartStop,
  });

  final TripAlert alert;
  final VoidCallback? onReviewReroute;
  final VoidCallback? onOpen;
  final VoidCallback? onConfirmArrival;
  final VoidCallback? onDepartStop;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final (borderColor, icon, severityLabel) = switch (alert.severity) {
      AlertSeverity.critical => (
        palette.error,
        Icons.warning_amber_rounded,
        'KHẨN CẤP',
      ),
      AlertSeverity.warning => (
        palette.warningText,
        Icons.schedule_rounded,
        'CẢNH BÁO',
      ),
      AlertSeverity.info => (
        palette.primary,
        Icons.info_outline_rounded,
        'THÔNG BÁO',
      ),
    };

    final localTimestamp = alert.timestamp.toLocal();
    final timeStr =
        '${localTimestamp.hour.toString().padLeft(2, '0')}:${localTimestamp.minute.toString().padLeft(2, '0')}';

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
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
                    Icon(Icons.done_all, size: 15, color: palette.secondary),
                  ],
                  const Spacer(),
                  Text(
                    timeStr,
                    style: TextStyle(color: palette.secondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                alert.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                alert.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.ink,
                  height: 1.35,
                ),
              ),
              if (alert.isResolved) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Đã xử lý',
                  style: TextStyle(
                    color: palette.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: palette.secondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      alert.affectedStopName,
                      style: TextStyle(color: palette.secondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (alert.type == TripAlertType.delay &&
                  !alert.isOverstay &&
                  !alert.isResolved &&
                  onConfirmArrival != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onConfirmArrival,
                    child: const Text('Xác nhận đã đến'),
                  ),
                ),
              ],
              if (alert.isOverstay &&
                  !alert.isResolved &&
                  onDepartStop != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onDepartStop,
                    child: const Text('Rời điểm ngay'),
                  ),
                ),
              ],
              if (alert.rerouteProposalAvailable &&
                  onReviewReroute != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: palette.border),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReviewReroute,
                    icon: const Icon(Icons.alt_route_rounded, size: 16),
                    label: const Text('Xem đề xuất đổi lộ trình'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: palette.primary,
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
