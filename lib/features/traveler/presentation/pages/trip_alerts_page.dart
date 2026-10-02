import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

class TripAlertsPage extends StatelessWidget {
  const TripAlertsPage({
    super.key,
    required this.itineraryId,
    this.alerts,
    this.isDemoMode = false,
  });

  final int itineraryId;
  final List<TripAlert>? alerts;
  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    // If wrapped in ActiveTripCubit, read from state; otherwise fallback to provided or demo
    final cubit = context.readOrNull<ActiveTripCubit>();
    final activeAlerts =
        alerts ??
        cubit?.state.alerts ??
        (isDemoMode
            ? ActiveTripDemoFixtures.createSampleAlerts()
            : const <TripAlert>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Alerts')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: AppColors.primarySoft,
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Trip #$itineraryId · ${activeAlerts.length} active alerts logged',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: activeAlerts.isEmpty
                  ? const Center(child: Text('No alerts found for this trip.'))
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

    return Card(
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
                  ),
                ),
                const Spacer(),
                Text(
                  '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              alert.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              alert.description,
              style: Theme.of(context).textTheme.bodySmall,
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
