import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

/// Isolated presentation section for Featured Central Vietnam Tours on Traveler Home
/// (SRS #44, #63, #64).
class TravelerTourDiscoverySection extends StatelessWidget {
  const TravelerTourDiscoverySection({super.key});

  static const defaultTours = [
    TourCardItem(
      id: 'hue',
      title: 'Khám phá Cố đô Huế & Ca Huế sông Hương',
      duration: '1 Ngày',
      rating: 4.9,
      price: 850000,
      tag: 'Gợi ý khám phá',
    ),
    TourCardItem(
      id: 'bana',
      title: 'Bà Nà Hills & Cầu Vàng trọn gói',
      duration: '1 Ngày',
      rating: 4.8,
      price: 1250000,
      tag: 'Gợi ý khám phá',
    ),
    TourCardItem(
      id: 'hoian',
      title: 'Hội An phố cổ & Rừng dừa Bảy Mẫu',
      duration: 'Nửa ngày',
      rating: 4.9,
      price: 650000,
      tag: 'Gợi ý khám phá',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tour nổi bật miền Trung',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.tourSearch),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: defaultTours.length,
            itemBuilder: (context, index) {
              final tour = defaultTours[index];
              return Container(
                width: 240,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () => context.push(AppRoutes.tourSearch),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tour.tag,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${tour.rating}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          tour.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tour.duration,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TripFormatters.formatCurrencyVnd(tour.price),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TourCardItem {
  const TourCardItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.rating,
    required this.price,
    required this.tag,
  });

  final String id;
  final String title;
  final String duration;
  final double rating;
  final int price;
  final String tag;
}
