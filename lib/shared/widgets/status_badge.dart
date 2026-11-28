import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
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
    final c = context.tmColors;
    final (foreground, background) = switch (type) {
      StatusBadgeType.neutral => (c.textSecondary, c.surfaceElevated),
      StatusBadgeType.info => (c.info, c.infoContainer),
      StatusBadgeType.success => (c.success, c.successContainer),
      StatusBadgeType.warning => (c.warning, c.warningContainer),
      StatusBadgeType.error => (c.error, c.errorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TripMateRadius.pill),
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
