import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/resources/operator_weather_safety_en.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

/// Status as icon plus text, so it never depends on colour alone.
class SafetyReviewStatusBadge extends StatelessWidget {
  const SafetyReviewStatusBadge({required this.status, super.key});

  final WeatherSafetyReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, type) = switch (status) {
      WeatherSafetyReviewStatus.pendingAcknowledgement => (
        Icons.schedule_rounded,
        AppColors.warning,
        StatusBadgeType.warning,
      ),
      WeatherSafetyReviewStatus.escalated => (
        Icons.priority_high_rounded,
        AppColors.error,
        StatusBadgeType.error,
      ),
      WeatherSafetyReviewStatus.acknowledged => (
        Icons.check_circle_outline,
        AppColors.success,
        StatusBadgeType.success,
      ),
      WeatherSafetyReviewStatus.closed => (
        Icons.lock_outline,
        AppColors.muted,
        StatusBadgeType.neutral,
      ),
      WeatherSafetyReviewStatus.unknown => (
        Icons.help_outline,
        AppColors.muted,
        StatusBadgeType.neutral,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: StatusBadge(
            label: OperatorWeatherSafetyStringsEn.reviewStatus(status),
            type: type,
          ),
        ),
      ],
    );
  }
}
