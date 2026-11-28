import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';

/// Destination item definition for [AppSlidingBottomNav].
class AppNavDestination {
  const AppNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge,
  });

  /// The label displayed below the icon.
  final String label;

  /// The icon displayed when this destination is inactive.
  final IconData icon;

  /// The icon displayed when this destination is active.
  final IconData selectedIcon;

  /// Optional text badge displayed near the icon (e.g. 'NEW', count).
  final String? badge;
}

/// A high-performance, mobile-first bottom navigation bar featuring a persistent
/// animated sliding highlight capsule, clear active/inactive distinction, a subtle
/// circular ripple feedback on tap, full accessibility semantics, and zero layout shifts.
///
/// Color overrides are optional and default to Coastal Heritage [TripMateColors]
/// via `context.tmColors`, adapting automatically to Light and Dark themes.
class AppSlidingBottomNav extends StatelessWidget {
  const AppSlidingBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.backgroundColor,
    this.highlightColor,
    this.activeColor,
    this.inactiveColor,
    this.borderColor,
    this.badgeColor,
    this.showHighlightCapsule = true,
    super.key,
  }) : assert(destinations.length >= 2, 'Must have at least 2 destinations'),
       assert(
         selectedIndex >= 0 && selectedIndex < destinations.length,
         'selectedIndex must be in range [0, destinations.length - 1]',
       );

  /// Currently selected tab index.
  final int selectedIndex;

  /// Callback invoked when a tab is tapped with its index.
  final ValueChanged<int> onDestinationSelected;

  /// List of tab destinations.
  final List<AppNavDestination> destinations;

  /// Background color of the navigation bar container.
  final Color? backgroundColor;

  /// Background color of the moving capsule indicator.
  final Color? highlightColor;

  /// Text and icon color for the active tab.
  final Color? activeColor;

  /// Text and icon color for inactive tabs.
  final Color? inactiveColor;

  /// Hairline top border color.
  final Color? borderColor;

  /// Accent badge background color.
  final Color? badgeColor;

  /// Whether to display a moving capsule background behind the active tab.
  /// Defaults to `true` to deliver the persistent sliding highlight experience.
  final bool showHighlightCapsule;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final count = destinations.length;

    final resolvedBg = backgroundColor ?? c.surfaceCard;
    final resolvedHighlight = highlightColor ?? c.tealSoftContainer;
    final resolvedActive = activeColor ?? c.brandTeal;
    final resolvedInactive = inactiveColor ?? c.textMuted;
    final resolvedBorder = borderColor ?? c.borderSubtle;
    final resolvedBadge = badgeColor ?? c.brandCoral;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: resolvedBg,
          border: Border(top: BorderSide(color: resolvedBorder, width: 1)),
          boxShadow: [
            BoxShadow(
              color: (c.isDark ? Colors.black : c.brandNavy).withValues(
                alpha: c.isDark ? 0.25 : 0.04,
              ),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final slotWidth = totalWidth / count;
                // Capsule width is proportional to slot width, clamped to comfortable bounds.
                final pillWidth = (slotWidth - 12).clamp(48.0, 72.0);
                final pillLeft =
                    selectedIndex * slotWidth + (slotWidth - pillWidth) / 2;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Moving highlight capsule (animates smoothly between tabs)
                    AnimatedPositioned(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      left: pillLeft,
                      top: 7,
                      width: pillWidth,
                      height: 46,
                      child: showHighlightCapsule
                          ? Container(
                              decoration: BoxDecoration(
                                color: resolvedHighlight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: resolvedActive.withValues(alpha: 0.14),
                                  width: 1.0,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Navigation items row
                    Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          _buildNavItem(
                            context: context,
                            index: i,
                            isSelected: i == selectedIndex,
                            destination: destinations[i],
                            disableAnimations: disableAnimations,
                            activeColor: resolvedActive,
                            inactiveColor: resolvedInactive,
                            badgeColor: resolvedBadge,
                            badgeTextColor: c.textOnCoralBadge,
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required bool isSelected,
    required AppNavDestination destination,
    required bool disableAnimations,
    required Color activeColor,
    required Color inactiveColor,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    final animDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            containedInkWell: false,
            highlightShape: BoxShape.circle,
            radius: 28,
            splashFactory: InkRipple.splashFactory,
            splashColor: activeColor.withValues(alpha: 0.16),
            highlightColor: activeColor.withValues(alpha: 0.08),
            hoverColor: activeColor.withValues(alpha: 0.04),
            onTap: () => onDestinationSelected(index),
            child: SizedBox(
              height: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.06 : 1.0,
                        duration: animDuration,
                        curve: Curves.easeOutBack,
                        child: Icon(
                          isSelected
                              ? destination.selectedIcon
                              : destination.icon,
                          size: isSelected ? 21 : 20,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                      if (destination.badge != null)
                        Positioned(
                          top: -3,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              destination.badge!,
                              style: TextStyle(
                                fontFamily: AppTypography.uiFont,
                                color: badgeTextColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: animDuration,
                    style: TextStyle(
                      fontFamily: AppTypography.uiFont,
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                      letterSpacing: isSelected ? -0.15 : 0.0,
                    ),
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
