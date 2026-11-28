import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

/// Canonical Coastal Heritage error state with soft error container badge,
/// optional title, readable guidance copy, and optional retry CTA.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    this.title,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryLabel = 'Thử lại',
    super.key,
  });

  final String message;
  final String? title;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: c.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: c.error),
              ),
              const SizedBox(height: AppSpacing.md),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.uiFont,
                    fontSize: 13.5,
                    height: 1.45,
                    color: c.textSecondary,
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: retryLabel, onPressed: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
