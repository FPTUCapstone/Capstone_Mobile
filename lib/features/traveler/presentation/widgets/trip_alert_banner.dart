import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

class TripAlertBanner extends StatelessWidget {
  const TripAlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
    this.onReviewReroute,
  });

  final TripAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback? onReviewReroute;

  @override
  Widget build(BuildContext context) {
    final (
      borderColor,
      bgColor,
      icon,
      severityLabel,
    ) = switch (alert.severity) {
      AlertSeverity.critical => (
        AppColors.error,
        const Color(0xFFFDECEF),
        Icons.warning_amber_rounded,
        'CRITICAL ALERT',
      ),
      AlertSeverity.warning => (
        AppColors.warning,
        const Color(0xFFFEF3E2),
        Icons.schedule_rounded,
        'WARNING',
      ),
      AlertSeverity.info => (
        AppColors.primary,
        AppColors.primarySoft,
        Icons.info_outline_rounded,
        'NOTICE',
      ),
    };

    return Semantics(
      container: true,
      label: '$severityLabel: ${alert.title}. ${alert.description}',
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: borderColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: borderColor, size: 18),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            severityLabel,
                            style: TextStyle(
                              color: borderColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            tooltip: 'Dismiss banner',
                            onPressed: onDismiss,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        alert.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.ink),
                      ),
                      if (alert.rerouteProposalAvailable &&
                          onReviewReroute != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: onReviewReroute,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Review proposal'),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
