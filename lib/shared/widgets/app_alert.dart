import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

enum AppAlertType { info, success, warning, error }

class AppAlert extends StatelessWidget {
  const AppAlert({
    required this.message,
    this.title,
    this.type = AppAlertType.info,
    super.key,
  });

  final String message;
  final String? title;
  final AppAlertType type;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final style = switch (type) {
      AppAlertType.info => _AlertStyle(
        c.info,
        c.infoContainer,
        Icons.info_outline,
      ),
      AppAlertType.success => _AlertStyle(
        c.success,
        c.successContainer,
        Icons.check_circle_outline,
      ),
      AppAlertType.warning => _AlertStyle(
        c.warning,
        c.warningContainer,
        Icons.warning_amber_rounded,
      ),
      AppAlertType.error => _AlertStyle(
        c.error,
        c.errorContainer,
        Icons.error_outline,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(TripMateRadius.sm),
          border: Border.all(color: style.foreground.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(style.icon, color: style.foreground, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: TextStyle(
                        fontFamily: AppTypography.uiFont,
                        fontSize: 13.5,
                        color: style.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: AppTypography.uiFont,
                      fontSize: 13,
                      height: 1.4,
                      color: style.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertStyle {
  const _AlertStyle(this.foreground, this.background, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;
}
