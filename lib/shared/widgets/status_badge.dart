import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

enum StatusBadgeType { neutral, info, success, warning, error }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.type = StatusBadgeType.neutral,
    super.key,
  });

  final String label;
  final StatusBadgeType type;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (type) {
      StatusBadgeType.neutral => (AppColors.muted, const Color(0xFFEDEAE1)),
      StatusBadgeType.info => (AppColors.primary, AppColors.primarySoft),
      StatusBadgeType.success => (AppColors.success, const Color(0xFFE5F6EF)),
      StatusBadgeType.warning => (AppColors.warning, const Color(0xFFFEF3E2)),
      StatusBadgeType.error => (AppColors.error, const Color(0xFFFDECEF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTypography.uiFont,
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}
