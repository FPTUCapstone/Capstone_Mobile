import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';

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

/// A high-performance, mobile-first bottom navigation bar featuring clear
/// active/inactive distinction, a subtle circular ripple feedback on tap,
/// full accessibility semantics, and zero layout shifts.
class AppSlidingBottomNav extends StatelessWidget {
  const AppSlidingBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.backgroundColor = Colors.white,
    this.highlightColor = AppColors.primarySoft,
    this.activeColor = AppColors.secondary,
    this.inactiveColor = AppColors.muted,
    this.showHighlightCapsule = false,
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
  final Color backgroundColor;

  /// Background color of the moving capsule indicator (if enabled).
  final Color highlightColor;

  /// Text and icon color for the active tab.
  final Color activeColor;

  /// Text and icon color for inactive tabs.
  final Color inactiveColor;

  /// Whether to display a moving capsule background behind the active tab.
  /// Defaults to `false` to avoid heavy block overlays and maintain a clean,
  /// modern native look with circular tap ripples.
  final bool showHighlightCapsule;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final count = destinations.length;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: const Border(
            top: BorderSide(color: AppColors.line, width: 0.8),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A00152A),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final slotWidth = totalWidth / count;
                // Capsule width is proportional to slot width, clamped to comfortable bounds.
                final pillWidth = (slotWidth - 10).clamp(48.0, 78.0);
                final pillLeft =
                    selectedIndex * slotWidth + (slotWidth - pillWidth) / 2;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Moving highlight capsule (hidden by default for clean native UI)
                    AnimatedPositioned(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: pillLeft,
                      top: 7,
                      width: pillWidth,
                      height: 50,
                      child: showHighlightCapsule
                          ? Container(
                              decoration: BoxDecoration(
                                color: highlightColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: activeColor.withValues(alpha: 0.22),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.08 : 1.0,
                        duration: animDuration,
                        curve: Curves.easeOutBack,
                        child: Icon(
                          isSelected
                              ? destination.selectedIcon
                              : destination.icon,
                          size: isSelected ? 22 : 21,
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
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              destination.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: animDuration,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                      letterSpacing: isSelected ? -0.2 : 0.0,
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
