import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/compact_horizontal_tour_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/featured_tour_editorial_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/search_continuation_strip.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/tour_discovery_feed_states.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_scroll_reveal.dart';

/// Variant A (Featured 16:9 + Compact Editorial Feed) for Traveler Home (SRS #44, #63, #64)
/// with full Motion System integration (MOTION-01 to MOTION-05).
class TravelerTourDiscoverySection extends StatelessWidget {
  const TravelerTourDiscoverySection({
    super.key,
    this.tours = TourDiscoveryItem.curatedDefault,
    this.feedState = TourDiscoveryFeedState.content,
    this.motionEnabled = true,
    this.reduceMotion = false,
    this.onTapTour,
    this.onRetryFeed,
    TourRevealCoordinator? revealCoordinator,
  }) : _revealCoordinator = revealCoordinator;

  final List<TourDiscoveryItem> tours;
  final TourDiscoveryFeedState feedState;
  final bool motionEnabled;
  final bool reduceMotion;
  final void Function(TourDiscoveryItem tour)? onTapTour;
  final VoidCallback? onRetryFeed;
  final TourRevealCoordinator? _revealCoordinator;

  static final TourRevealCoordinator _fallbackCoordinator =
      TourRevealCoordinator();

  void _handleTourTap(
    BuildContext context,
    TourDiscoveryItem tour,
    String heroTag,
  ) {
    if (onTapTour != null) {
      onTapTour!(tour);
    } else {
      context.push(
        AppRoutes.tourDetail(tour.id, heroTag: heroTag),
        extra: tour.toSummary(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 375;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final disableAnim =
        reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !motionEnabled;
    final coordinator = _revealCoordinator ?? _fallbackCoordinator;

    Widget stateBody;
    switch (feedState) {
      case TourDiscoveryFeedState.loading:
        stateBody = const KeyedSubtree(
          key: ValueKey('tour_feed_loading'),
          child: TourDiscoveryMotionSkeleton(),
        );
      case TourDiscoveryFeedState.empty:
        stateBody = KeyedSubtree(
          key: const ValueKey('tour_feed_empty'),
          child: TourDiscoveryEmptyView(
            onTapSearch: () => context.push(AppRoutes.tourSearch),
          ),
        );
      case TourDiscoveryFeedState.error:
        stateBody = KeyedSubtree(
          key: const ValueKey('tour_feed_error'),
          child: TourDiscoveryErrorView(
            onRetry: onRetryFeed ?? () {},
            onTapSearch: () => context.push(AppRoutes.tourSearch),
          ),
        );
      case TourDiscoveryFeedState.content:
        if (tours.isEmpty) {
          stateBody = KeyedSubtree(
            key: const ValueKey('tour_feed_empty_list'),
            child: TourDiscoveryEmptyView(
              onTapSearch: () => context.push(AppRoutes.tourSearch),
            ),
          );
          break;
        }

        final featured = tours.first;
        final subsequent = tours.skip(1).take(2).toList(growable: false);
        final featuredHeroTag = 'home_featured_${featured.id}';

        stateBody = KeyedSubtree(
          key: const ValueKey('tour_feed_content_a'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EditorialScrollReveal(
                itemKey: 'reveal_home_featured_${featured.id}',
                coordinator: coordinator,
                enabled: motionEnabled,
                reduceMotion: reduceMotion,
                staggerIndex: 0,
                child: FeaturedTourEditorialCard(
                  tour: featured,
                  heroTag: featuredHeroTag,
                  compact: compact,
                  enlargedText: enlargedText,
                  motionEnabled: motionEnabled,
                  reduceMotion: reduceMotion,
                  onTap: () =>
                      _handleTourTap(context, featured, featuredHeroTag),
                ),
              ),
              for (var i = 0; i < subsequent.length; i++) ...[
                const SizedBox(height: 10),
                () {
                  final compactHeroTag = 'home_compact_${subsequent[i].id}';
                  return EditorialScrollReveal(
                    itemKey: 'reveal_home_compact_${subsequent[i].id}',
                    coordinator: coordinator,
                    enabled: motionEnabled,
                    reduceMotion: reduceMotion,
                    staggerIndex: i + 1,
                    child: CompactHorizontalTourCard(
                      tour: subsequent[i],
                      heroTag: compactHeroTag,
                      compact: compact,
                      enlargedText: enlargedText,
                      motionEnabled: motionEnabled,
                      reduceMotion: reduceMotion,
                      onTap: () => _handleTourTap(
                        context,
                        subsequent[i],
                        compactHeroTag,
                      ),
                    ),
                  );
                }(),
              ],
              const SizedBox(height: 12),
              EditorialScrollReveal(
                itemKey: 'reveal_home_continuation',
                coordinator: coordinator,
                enabled: motionEnabled,
                reduceMotion: reduceMotion,
                staggerIndex: subsequent.length + 1,
                child: SearchContinuationStrip(
                  enlargedText: enlargedText,
                  onTap: () => context.push(AppRoutes.tourSearch),
                ),
              ),
            ],
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tour nổi bật miền Trung',
              style: TextStyle(
                fontFamily: AppTypography.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: c.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.tourSearch),
              style: TextButton.styleFrom(
                foregroundColor: c.brandTeal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSize(
          duration: disableAnim
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: disableAnim
                ? Duration.zero
                : const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: stateBody,
          ),
        ),
      ],
    );
  }
}
