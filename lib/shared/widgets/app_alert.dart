import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

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
    final style = switch (type) {
      AppAlertType.info => const _AlertStyle(
        AppColors.primary,
        AppColors.primarySoft,
        Icons.info_outline,
      ),
      AppAlertType.success => const _AlertStyle(
        AppColors.success,
        Color(0xFFE6F7F0),
        Icons.check_circle_outline,
      ),
      AppAlertType.warning => const _AlertStyle(
        AppColors.warning,
        Color(0xFFFEF3E2),
        Icons.warning_amber_rounded,
      ),
      AppAlertType.error => const _AlertStyle(
        AppColors.error,
        Color(0xFFFDECEF),
        Icons.error_outline,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                  if (title != null)
                    Text(
                      title!,
                      style: TextStyle(
                        color: style.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(message, style: TextStyle(color: style.foreground)),
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
