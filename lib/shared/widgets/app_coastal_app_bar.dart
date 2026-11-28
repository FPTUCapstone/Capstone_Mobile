import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

/// Canonical Coastal Heritage flat AppBar with a 1px hairline divider and
/// optional [subtitle], adapting automatically to Light and Dark themes.
///
/// Used across Templates T2, T3, and T4 (see `DESIGN.md`).
class AppCoastalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppCoastalAppBar({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.showBottomDivider = true,
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final bool showBottomDivider;
  final PreferredSizeWidget? bottom;

  bool get _hasSubtitle => subtitle != null && subtitle!.trim().isNotEmpty;

  double get _toolbarHeight => _hasSubtitle ? 58.0 : 52.0;

  @override
  Size get preferredSize {
    final bottomHeight =
        bottom?.preferredSize.height ?? (showBottomDivider ? 1.0 : 0.0);
    return Size.fromHeight(_toolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final hasSubtitle = _hasSubtitle;

    final titleWidget = hasSubtitle
        ? Column(
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
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
        : Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.displayFont,
              fontSize: 17.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: c.textPrimary,
            ),
          );

    return AppBar(
      title: titleWidget,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: _toolbarHeight,
      backgroundColor: c.surfaceCard,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom:
          bottom ??
          (showBottomDivider
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: c.borderSubtle,
                  ),
                )
              : null),
    );
  }
}
