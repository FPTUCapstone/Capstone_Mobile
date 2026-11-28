import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

/// Canonical Template T2 (Standard Scroll / Form Page) for TripMate Mobile.
///
/// Provides a warm Coastal Heritage canvas, a flat hairline-bordered AppBar
/// (with optional [subtitle], [leading], and [actions]), centered responsive
/// content constrained to [maxWidth], drag-to-dismiss keyboard behavior,
/// optional pull-to-refresh ([onRefresh]), and an optional pinned [bottomBar].
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.content,
    this.actions,
    this.bottomBar,
    this.centerTitle = false,
    this.floatingActionButton,
    this.footer,
    this.leading,
    this.maxWidth = 520,
    this.onRefresh,
    this.padding,
    this.showAppBar = true,
    this.subtitle,
    this.title,
    super.key,
  });

  final List<Widget>? actions;
  final Widget? bottomBar;
  final bool centerTitle;
  final List<Widget> content;
  final Widget? floatingActionButton;
  final Widget? footer;
  final Widget? leading;
  final double maxWidth;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;
  final bool showAppBar;
  final String? subtitle;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    Widget? titleWidget;
    if (title != null) {
      titleWidget = hasSubtitle
          ? Column(
              crossAxisAlignment: centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ],
            )
          : Text(title!);
    }

    final listView = ListView(
      physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
      children: [
        ...content,
        if (footer != null) ...[const SizedBox(height: AppSpacing.lg), footer!],
      ],
    );

    final scrollBody = onRefresh != null
        ? RefreshIndicator(
            color: c.brandTeal,
            onRefresh: onRefresh!,
            child: listView,
          )
        : listView;

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: showAppBar
          ? AppBar(
              leading: leading,
              centerTitle: centerTitle,
              toolbarHeight: hasSubtitle ? 58 : 52,
              title: titleWidget,
              actions: actions,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: c.borderSubtle.withValues(alpha: 0.7),
                ),
              ),
            )
          : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: SafeArea(
        bottom: bottomBar == null,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: scrollBody,
          ),
        ),
      ),
    );
  }
}
