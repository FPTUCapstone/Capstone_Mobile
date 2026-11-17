import 'package:flutter/material.dart';

/// Shared Hero wrapper for MOTION-04 ensuring rounded image geometry flies
/// smoothly without hard corner pops during navigation.
class EditorialTourHero extends StatelessWidget {
  const EditorialTourHero({
    super.key,
    required this.heroTag,
    required this.borderRadius,
    required this.child,
  });

  final String? heroTag;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (heroTag == null) return child;
    return Hero(
      tag: heroTag!,
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            final fromHero = fromHeroContext.widget as Hero;
            final toHero = toHeroContext.widget as Hero;
            final fromClip = fromHero.child is ClipRRect
                ? (fromHero.child as ClipRRect).borderRadius as BorderRadius?
                : null;
            final toClip = toHero.child is ClipRRect
                ? (toHero.child as ClipRRect).borderRadius as BorderRadius?
                : null;
            final startRadius = fromClip ?? BorderRadius.zero;
            final endRadius = toClip ?? BorderRadius.zero;
            final shuttle = flightDirection == HeroFlightDirection.push
                ? toHero.child
                : fromHero.child;
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return AnimatedBuilder(
              animation: curved,
              child: shuttle,
              builder: (ctx, c) {
                final currentRadius = BorderRadius.lerp(
                  startRadius,
                  endRadius,
                  curved.value,
                )!;
                return ClipRRect(borderRadius: currentRadius, child: c);
              },
            );
          },
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}
