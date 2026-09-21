import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';

class TourListCard extends StatelessWidget {
  const TourListCard({required this.tour, super.key});

  final TourSummary tour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${tour.title}, ${_availabilityLabel(tour)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TourSearchPalette.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14102A43),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────────────
              Text(
                tour.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: TourSearchPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),

              // ── Destinations ───────────────────────────────────────
              if (tour.destinations.isNotEmpty)
                Text(
                  tour.destinations.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: TourSearchPalette.muted,
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),

              // ── Operator & Duration ────────────────────────────────
              Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 16,
                    color: TourSearchPalette.muted,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(
                      tour.operatorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: TourSearchPalette.navyLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: TourSearchPalette.muted,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    '${tour.durationDays} ngày',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: TourSearchPalette.navyLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Price & Availability ───────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      _formatPrice(tour.basePrice, tour.currency),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: TourSearchPalette.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _AvailabilityBadge(tour: tour),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPrice(int price, String currency) {
    final text = price.toString();
    final buffer = StringBuffer();
    final length = text.length;
    for (var i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(text[i]);
    }
    final normalizedCurrency = currency.trim().toUpperCase();
    if (normalizedCurrency == 'VND') {
      buffer.write('₫');
    } else if (normalizedCurrency.isNotEmpty) {
      buffer.write(' $normalizedCurrency');
    }
    return buffer.toString();
  }

  static String _availabilityLabel(TourSummary tour) {
    return switch (tour.availabilityStatus) {
      AvailabilityStatus.available => 'Còn ${tour.remainingSlots ?? '?'} chỗ',
      AvailabilityStatus.soldOut => 'Hết chỗ',
      AvailabilityStatus.noUpcomingSchedule => 'Chưa có lịch khởi hành',
      AvailabilityStatus.unknown => 'Tình trạng chỗ chưa xác định',
    };
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.tour});

  final TourSummary tour;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (tour.availabilityStatus) {
      AvailabilityStatus.available => (
        _availableLabel(),
        TourSearchPalette.available,
        Icons.event_available_outlined,
      ),
      AvailabilityStatus.soldOut => (
        'Hết chỗ',
        TourSearchPalette.soldOut,
        Icons.event_busy_outlined,
      ),
      AvailabilityStatus.noUpcomingSchedule => (
        'Chưa có lịch khởi hành',
        TourSearchPalette.muted,
        Icons.event_outlined,
      ),
      AvailabilityStatus.unknown => (
        'Tình trạng chỗ chưa xác định',
        TourSearchPalette.muted,
        Icons.help_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _availableLabel() {
    final parts = <String>[];
    if (tour.remainingSlots != null) {
      parts.add('Còn ${tour.remainingSlots} chỗ');
    }
    if (tour.departureAtUtc != null) {
      final vn = tour.departureAtUtc!.add(const Duration(hours: 7));
      final day = vn.day.toString().padLeft(2, '0');
      final month = vn.month.toString().padLeft(2, '0');
      parts.add('$day/$month/${vn.year}');
    }
    return parts.isEmpty ? 'Có chỗ' : parts.join(' • ');
  }
}
