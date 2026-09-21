import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';

class PoiOpenStatus extends StatelessWidget {
  const PoiOpenStatus({required this.isOpen, super.key});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? PoiPalette.success : PoiPalette.muted;
    return Semantics(
      label: isOpen ? 'Đang mở cửa' : 'Đã đóng',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isOpen ? 'Đang mở cửa' : 'Đã đóng',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PoiRating extends StatelessWidget {
  const PoiRating({required this.rating, required this.reviewCount, super.key});

  final double? rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Text(
        'Chưa có đánh giá',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: PoiPalette.muted),
      );
    }
    return Semantics(
      label: '${rating!.toStringAsFixed(1)} sao, $reviewCount đánh giá',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: PoiPalette.rating, size: 20),
          Text(
            rating!.toStringAsFixed(1).replaceAll('.', ','),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: PoiPalette.rating,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '(${_compact(reviewCount)})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: PoiPalette.muted),
            ),
          ),
        ],
      ),
    );
  }

  String _compact(int value) {
    if (value < 1000) return '$value';
    final formatted = (value / 1000).toStringAsFixed(1).replaceAll('.', ',');
    return '${formatted}K';
  }
}
