import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/tour_discovery_meta_widgets.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

class FeaturedTourEditorialCard extends StatelessWidget {
  const FeaturedTourEditorialCard({
    super.key,
    required this.tour,
    required this.onTap,
    this.compact = false,
    this.enlargedText = false,
    this.imageBuilder,
  });

  final TourDiscoveryItem tour;
  final VoidCallback onTap;
  final bool compact;
  final bool enlargedText;
  final Widget Function(BuildContext context, Widget defaultImage)?
  imageBuilder;

  String _formatSchedule(TourDiscoveryItem item) {
    if (item.availabilityStatus == AvailabilityStatus.soldOut) {
      return 'Hết chỗ';
    }
    if (item.departureAtUtc != null) {
      final d = item.departureAtUtc!.day.toString().padLeft(2, '0');
      final m = item.departureAtUtc!.month.toString().padLeft(2, '0');
      if (item.remainingSlots != null) {
        return 'Khởi hành $d/$m · Còn ${item.remainingSlots} chỗ';
      }
      return 'Khởi hành $d/$m';
    }
    if (item.remainingSlots != null) {
      return 'Còn ${item.remainingSlots} chỗ';
    }
    return '${item.durationDays} ngày';
  }

  Widget _buildDefaultImage() {
    final url = tour.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFFE2E8F0),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 36, color: Colors.grey),
        ),
      );
    }
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        semanticLabel: 'Ảnh tour ${tour.title}',
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      semanticLabel: 'Ảnh tour ${tour.title}',
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFE2E8F0),
        child: const Center(
          child: Icon(Icons.broken_image, size: 36, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final soldOut = tour.availabilityStatus == AvailabilityStatus.soldOut;
    final scheduleSummary = _formatSchedule(tour);
    final stackFooter = compact && enlargedText;

    final imageWidget = imageBuilder != null
        ? imageBuilder!(context, _buildDefaultImage())
        : _buildDefaultImage();

    return Material(
      color: c.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: imageWidget,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 16,
                  12,
                  compact ? 14 : 16,
                  14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${tour.destinations} · ${tour.durationDays} ngày',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.uiFont,
                              color: c.brandTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (tour.rating != null) ...[
                          const SizedBox(width: 8),
                          RatingInline(rating: tour.rating!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tour.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.displayFont,
                        color: c.textPrimary,
                        fontSize: compact ? 15.5 : 16.5,
                        fontWeight: FontWeight.w700,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: c.borderSubtle.withValues(alpha: 0.75),
                    ),
                    const SizedBox(height: 10),
                    if (stackFooter)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OperatorAndScheduleMeta(
                            operatorName: tour.operatorName,
                            scheduleText: scheduleSummary,
                            isSoldOut: soldOut,
                          ),
                          const SizedBox(height: 8),
                          PriceAnchor(priceVnd: tour.priceVnd, alignEnd: false),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: OperatorAndScheduleMeta(
                              operatorName: tour.operatorName,
                              scheduleText: scheduleSummary,
                              isSoldOut: soldOut,
                            ),
                          ),
                          const SizedBox(width: 12),
                          PriceAnchor(priceVnd: tour.priceVnd, alignEnd: true),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
