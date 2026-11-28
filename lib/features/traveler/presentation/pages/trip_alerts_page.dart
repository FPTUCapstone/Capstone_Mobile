import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';

class TripAlertsPage extends StatelessWidget {
  const TripAlertsPage({super.key, required this.itineraryId, this.alerts});

  final int itineraryId;
  final List<TripAlert>? alerts;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    // If wrapped in ActiveTripCubit, read from state; otherwise use the provided list.
    final cubit = context.readOrNull<ActiveTripCubit>();
    final activeAlerts = alerts ?? cubit?.state.alerts ?? const <TripAlert>[];

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(title: 'Cảnh báo chuyến đi'),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: c.tealSoftContainer,
                border: Border(bottom: BorderSide(color: c.borderSubtle)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: c.brandTeal),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Chuyến đi #$itineraryId · ${activeAlerts.length} cảnh báo đang hoạt động',
                      style: TextStyle(
                        color: c.brandTeal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: activeAlerts.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Không có cảnh báo nào cho chuyến đi này.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: activeAlerts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final alert = activeAlerts[index];
                        return _AlertItemCard(alert: alert);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertItemCard extends StatelessWidget {
  const _AlertItemCard({required this.alert});

  final TripAlert alert;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final (
      accentColor,
      badgeBg,
      icon,
      severityLabel,
    ) = switch (alert.severity) {
      AlertSeverity.critical => (
        c.error,
        c.errorContainer,
        Icons.warning_amber_rounded,
        'KHẨN CẤP',
      ),
      AlertSeverity.warning => (
        c.warning,
        c.warningContainer,
        Icons.schedule_rounded,
        'CẢNH BÁO',
      ),
      AlertSeverity.info => (
        c.brandTeal,
        c.tealSoftContainer,
        Icons.info_outline_rounded,
        'THÔNG BÁO',
      ),
    };

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TripMateRadius.lg),
          border: Border(left: BorderSide(color: accentColor, width: 4)),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: accentColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        severityLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              alert.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              alert.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _ReadOrNull on BuildContext {
  T? readOrNull<T>() {
    try {
      return read<T>();
    } catch (_) {
      return null;
    }
  }
}
