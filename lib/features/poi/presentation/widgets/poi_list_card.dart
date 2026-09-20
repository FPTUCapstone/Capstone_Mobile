import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_status_and_rating.dart';

class PoiListCard extends StatelessWidget {
  const PoiListCard({required this.poi, required this.onTap, super.key});

  final PoiSummary poi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Xem chi tiết ${poi.name}',
      child: Card(
        key: Key('poi-card-${poi.id}'),
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageSize = constraints.maxWidth < 300 ? 72.0 : 84.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.square(
                        dimension: imageSize,
                        child: PoiImage(
                          url: poi.thumbnailUrl,
                          semanticLabel: 'Ảnh ${poi.name}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: PoiPalette.navy,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Badge(label: poi.categoryName),
                              if (poi.distanceKm != null)
                                _Badge(
                                  label:
                                      '${poi.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                                  neutral: true,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              PoiOpenStatus(isOpen: poi.isOpenNow),
                              PoiRating(
                                rating: poi.averageRating,
                                reviewCount: poi.reviewCount,
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.neutral = false});

  final String label;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: neutral ? PoiPalette.background : PoiPalette.tealSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: neutral ? PoiPalette.navy : PoiPalette.teal,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
