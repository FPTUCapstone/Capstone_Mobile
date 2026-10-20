import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

/// Standard container card for TripMate Voyager.
///
/// White surface with 1px border (#E2E8F0), 12dp rounded corners, and optional
/// tap interaction with subtle splash.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor = Colors.white,
    this.borderColor = AppColors.line,
    this.borderRadius = 12.0,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BorderSide(color: borderColor, width: 1),
    );

    if (onTap != null) {
      return Material(
        color: backgroundColor,
        shape: border,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      );
    }

    return Container(
      decoration: ShapeDecoration(color: backgroundColor, shape: border),
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }
}
