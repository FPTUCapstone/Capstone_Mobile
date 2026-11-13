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

/// Variant A (Featured 16:9 + Compact Editorial Feed) for Traveler Home (SRS #44, #63, #64).
class TravelerTourDiscoverySection extends StatelessWidget {
  const TravelerTourDiscoverySection({
    super.key,
    this.tours = TourDiscoveryItem.curatedDefault,
    this.onTapTour,
  });

  final List<TourDiscoveryItem> tours;
  final void Function(TourDiscoveryItem tour)? onTapTour;

  void _handleTourTap(BuildContext context, TourDiscoveryItem tour) {
    if (onTapTour != null) {
      onTapTour!(tour);
    } else {
      context.push(AppRoutes.tourDetail(tour.id), extra: tour.toSummary());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tours.isEmpty) {
      return const SizedBox.shrink();
    }

    final c = context.tmColors;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 375;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.15;

    final featured = tours.first;
    final subsequent = tours.skip(1).take(2).toList(growable: false);

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
        FeaturedTourEditorialCard(
          tour: featured,
          compact: compact,
          enlargedText: enlargedText,
          onTap: () => _handleTourTap(context, featured),
        ),
        for (final item in subsequent) ...[
          const SizedBox(height: 10),
          CompactHorizontalTourCard(
            tour: item,
            compact: compact,
            enlargedText: enlargedText,
            onTap: () => _handleTourTap(context, item),
          ),
        ],
        const SizedBox(height: 12),
        SearchContinuationStrip(
          enlargedText: enlargedText,
          onTap: () => context.push(AppRoutes.tourSearch),
        ),
      ],
    );
  }
}
