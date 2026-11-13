import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/tour_discovery_meta_widgets.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_parallax_image.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_tactile_card.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_tour_hero.dart';

class CompactHorizontalTourCard extends StatelessWidget {
  const CompactHorizontalTourCard({
    super.key,
    required this.tour,
    required this.onTap,
    this.heroTag,
    this.compact = false,
    this.enlargedText = false,
    this.motionEnabled = true,
    this.reduceMotion = false,
    this.imageBuilder,
  });

  final TourDiscoveryItem tour;
  final VoidCallback onTap;
  final String? heroTag;
  final bool compact;
  final bool enlargedText;
  final bool motionEnabled;
  final bool reduceMotion;
  final Widget Function(BuildContext context, Widget defaultImage)?
  imageBuilder;

  String _formatCompactDuration(TourDiscoveryItem item) {
    final durationText = '${item.durationDays} ngày';
    if (item.availabilityStatus == AvailabilityStatus.soldOut) {
      return '$durationText · Hết chỗ';
    }
    if (item.departureAtUtc != null) {
      final d = item.departureAtUtc!.day.toString().padLeft(2, '0');
      final m = item.departureAtUtc!.month.toString().padLeft(2, '0');
      return '$durationText · $d/$m';
    }
    return durationText;
  }

  Widget _buildDefaultImage() {
    final url = tour.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFFE2E8F0),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 28, color: Colors.grey),
        ),
      );
    }
    return EditorialParallaxImage(
      imageUrl: url,
      semanticLabel: 'Ảnh tour ${tour.title}',
      axis: Axis.vertical,
      maxDisplacement: 6,
      cacheWidth: 360,
      enabled: motionEnabled,
      reduceMotion: reduceMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final soldOut = tour.availabilityStatus == AvailabilityStatus.soldOut;
    final thumbWidth = (compact && enlargedText)
        ? 76.0
        : (compact ? 88.0 : 96.0);
    final thumbHeight = (compact && enlargedText)
        ? 86.0
        : (compact ? 92.0 : 96.0);
    final pad = compact ? 10.0 : 12.0;

    final imageWidget = imageBuilder != null
        ? imageBuilder!(context, _buildDefaultImage())
        : _buildDefaultImage();

    return EditorialTactileCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      backgroundColor: c.surfaceCard,
      borderColor: c.borderSubtle,
      enabled: motionEnabled,
      reduceMotion: reduceMotion,
      semanticLabel:
          '${tour.title}, ${tour.durationDays} ngày, từ ${TripFormatters.formatCurrencyVnd(tour.priceVnd)}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: EdgeInsets.all(pad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: thumbWidth,
              height: thumbHeight,
              child: EditorialTourHero(
                heroTag: heroTag,
                borderRadius: BorderRadius.circular(10),
                child: imageWidget,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tour.destinations,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.uiFont,
                            color: c.brandTeal,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (tour.rating != null) ...[
                        const SizedBox(width: 6),
                        RatingInline(rating: tour.rating!, fontSize: 11.5),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tour.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.displayFont,
                      color: c.textPrimary,
                      fontSize: (compact && enlargedText)
                          ? 13.5
                          : (compact ? 14 : 14.5),
                      fontWeight: FontWeight.w700,
                      height: 1.26,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tour.operatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.uiFont,
                      color: c.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (compact && enlargedText)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCompactDuration(tour),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.uiFont,
                            color: soldOut ? c.error : c.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        InlinePriceWithUnit(priceVnd: tour.priceVnd),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            _formatCompactDuration(tour),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.uiFont,
                              color: soldOut ? c.error : c.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InlinePriceWithUnit(
                          priceVnd: tour.priceVnd,
                          showUnit: false,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
