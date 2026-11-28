import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

/// Canonical Template T3 thumb-zone sticky bottom action bar.
///
/// Renders a hairline-bordered [TripMateColors.surfaceCard] bar pinned at the
/// bottom of a [Scaffold] with [SafeArea] bottom inset protection. Supports
/// three common mobile layouts:
/// - [summary] + [primaryAction] (e.g. Tour Detail price + Book Now)
/// - [secondaryAction] + [primaryAction] (e.g. Decline / Accept proposal)
/// - Full-width [primaryAction] or custom [child]
class AppStickyActionBar extends StatelessWidget {
  const AppStickyActionBar({
    this.child,
    this.summary,
    this.primaryAction,
    this.secondaryAction,
    this.padding,
    super.key,
  }) : assert(
         child != null || primaryAction != null || secondaryAction != null,
         'Provide child, primaryAction, or secondaryAction.',
       );

  final Widget? child;
  final Widget? summary;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;

    final Widget content;
    if (child != null) {
      content = child!;
    } else if (summary != null && primaryAction != null) {
      content = Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [summary!, primaryAction!],
      );
    } else if (secondaryAction != null && primaryAction != null) {
      content = Row(
        children: [
          Expanded(child: secondaryAction!),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: primaryAction!),
        ],
      );
    } else {
      content = SizedBox(
        width: double.infinity,
        child: primaryAction ?? secondaryAction!,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceCard,
        border: Border(top: BorderSide(color: c.borderSubtle, width: 1)),
        boxShadow: [
          BoxShadow(
            color: (c.isDark ? Colors.black : c.brandNavy).withValues(
              alpha: c.isDark ? 0.24 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.fromLTRB(
                AppSpacing.md,
                10,
                AppSpacing.md,
                AppSpacing.sm,
              ),
          child: content,
        ),
      ),
    );
  }
}
