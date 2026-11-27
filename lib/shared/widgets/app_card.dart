import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';

/// Standard container card for TripMate Voyager.
///
/// White surface with 1px border (#E2E8F0), 12dp rounded corners, and optional
/// tap interaction with subtle splash.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14.0,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final resolvedBg = backgroundColor ?? c.surfaceCard;
    final resolvedBorder = borderColor ?? c.borderSubtle;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BorderSide(color: resolvedBorder, width: 1),
    );

    if (onTap != null) {
      return Material(
        color: resolvedBg,
        shape: border,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(14),
            child: child,
          ),
        ),
      );
    }

    return Container(
      decoration: ShapeDecoration(color: resolvedBg, shape: border),
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }
}
