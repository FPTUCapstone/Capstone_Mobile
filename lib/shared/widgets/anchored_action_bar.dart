import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';

/// A bar anchored to the bottom of a page, for use as
/// `Scaffold.bottomNavigationBar`.
///
/// It respects the bottom safe area, is capped to a share of the screen height
/// (scrolling internally) so it can never hide the page content at large text
/// sizes, and is hidden by the keyboard like any bottom bar.
class AnchoredActionBar extends StatelessWidget {
  const AnchoredActionBar({required this.child, super.key});

  final Widget child;

  static const _maxWidth = 520.0;
  static const _maxHeightFraction = 0.4;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * _maxHeightFraction;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _maxWidth,
              maxHeight: maxHeight,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
