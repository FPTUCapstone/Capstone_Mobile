import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

/// Canonical Coastal Heritage titled section card for forms, checkout summaries,
/// and detail screens (Templates T2 & T3).
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.trailing,
    this.backgroundColor,
    this.borderColor,
    this.padding,
    this.borderRadius = 14.0,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final hasHeader = title != null || icon != null || trailing != null;

    return AppCard(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderRadius: borderRadius,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: iconBackgroundColor ?? c.tealSoftContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: iconColor ?? c.brandTeal,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (title != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title!,
                          style: TextStyle(
                            fontFamily: AppTypography.uiFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontFamily: AppTypography.uiFont,
                              fontSize: 12,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }
}

/// Aligned label + value summary row used inside [AppSectionCard] for booking
/// quotes, payment receipts, and refund timelines.
class AppKeyValueRow extends StatelessWidget {
  const AppKeyValueRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.subtitle,
    this.isProminent = false,
    this.isPrice = false,
    this.valueColor,
    super.key,
  }) : assert(
         value != null || valueWidget != null,
         'Provide either value or valueWidget.',
       );

  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? subtitle;
  final bool isProminent;
  final bool isPrice;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final resolvedValueColor =
        valueColor ?? (isProminent ? c.brandTeal : c.textPrimary);

    final TextStyle valueStyle;
    if (isPrice) {
      valueStyle = AppTypography.price(
        resolvedValueColor,
        fontSize: isProminent ? 18 : 14,
      );
    } else {
      valueStyle = TextStyle(
        fontFamily: AppTypography.uiFont,
        fontSize: isProminent ? 16 : 13.5,
        fontWeight: isProminent ? FontWeight.w800 : FontWeight.w700,
        color: resolvedValueColor,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.uiFont,
                  fontSize: isProminent ? 14 : 13.5,
                  fontWeight: isProminent ? FontWeight.w600 : FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontFamily: AppTypography.uiFont,
                    fontSize: 11.5,
                    color: c.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child:
              valueWidget ??
              Text(value!, textAlign: TextAlign.end, style: valueStyle),
        ),
      ],
    );
  }
}
