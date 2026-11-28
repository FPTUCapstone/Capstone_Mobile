import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/resources/public_search_copy.dart';

class TourListCard extends StatelessWidget {
  const TourListCard({
    required this.tour,
    this.onTap,
    this.matchingScore,
    this.useEnglish = false,
    super.key,
  });

  final TourSummary tour;
  final VoidCallback? onTap;
  final double? matchingScore;
  final bool useEnglish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.tmColors;
    final cardContent = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TourThumbnail(tour: tour, useEnglish: useEnglish),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (matchingScore != null) ...[
                      _MatchingScoreBadge(score: matchingScore!),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    // ── Title ──────────────────────────────────────────────
                    Text(
                      tour.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
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
                          color: c.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 6),

                    // ── Operator & Duration ────────────────────────────────
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 14,
                          color: c.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(
                            tour.operatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: c.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          publicSearchDays(tour.durationDays, useEnglish),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (tour.aggregateRating != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: c.brandCoral,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            tour.aggregateRating!.toString(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: c.borderSubtle),
          const SizedBox(height: 8),
          // ── Price & Availability ───────────────────────────────
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              Text(
                _formatPrice(tour.basePrice, tour.currency),
                style: AppTypography.price(c.brandTeal, fontSize: 15.5),
              ),
              _AvailabilityBadge(tour: tour, useEnglish: useEnglish),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      label:
          '${tour.title}, ${_availabilityLabel(tour, useEnglish)}${matchingScore != null ? ', ${(matchingScore! * 100).round()}% phù hợp' : ''}',
      button: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderSubtle),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: cardContent,
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

  static String _availabilityLabel(TourSummary tour, bool useEnglish) {
    return switch (tour.availabilityStatus) {
      AvailabilityStatus.available => publicSearchSlots(
        tour.remainingSlots,
        useEnglish,
      ),
      AvailabilityStatus.soldOut => publicSearchCopy(
        SearchText.soldOut,
        useEnglish,
      ),
      AvailabilityStatus.noUpcomingSchedule => publicSearchCopy(
        SearchText.noSchedule,
        useEnglish,
      ),
      AvailabilityStatus.unknown => publicSearchCopy(
        SearchText.unknown,
        useEnglish,
      ),
    };
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.tour, required this.useEnglish});

  final TourSummary tour;
  final bool useEnglish;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final (label, color, icon) = switch (tour.availabilityStatus) {
      AvailabilityStatus.available => (
        _availableLabel(),
        c.success,
        Icons.event_available_outlined,
      ),
      AvailabilityStatus.soldOut => (
        publicSearchCopy(SearchText.soldOut, useEnglish),
        c.error,
        Icons.event_busy_outlined,
      ),
      AvailabilityStatus.noUpcomingSchedule => (
        publicSearchCopy(SearchText.noSchedule, useEnglish),
        c.textMuted,
        Icons.event_outlined,
      ),
      AvailabilityStatus.unknown => (
        publicSearchCopy(SearchText.unknown, useEnglish),
        c.textMuted,
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
    if (useEnglish) return publicSearchSlots(tour.remainingSlots, true);
    final parts = <String>[];
    if (tour.remainingSlots != null) {
      parts.add(publicSearchSlots(tour.remainingSlots, false));
    }
    if (tour.departureAtUtc != null) {
      final vn = tour.departureAtUtc!.add(const Duration(hours: 7));
      final day = vn.day.toString().padLeft(2, '0');
      final month = vn.month.toString().padLeft(2, '0');
      parts.add('$day/$month/${vn.year}');
    }
    return parts.isEmpty
        ? publicSearchCopy(SearchText.available, false)
        : parts.join(' • ');
  }
}

class _TourThumbnail extends StatelessWidget {
  const _TourThumbnail({required this.tour, required this.useEnglish});

  final TourSummary tour;
  final bool useEnglish;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final rawUrl = tour.thumbnailUrl?.trim();
    final hasValidUrl = rawUrl != null && rawUrl.isNotEmpty;

    return Container(
      key: Key('tour-thumbnail-${tour.tourId}'),
      width: 88,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderSubtle),
      ),
      child: hasValidUrl
          ? Image.network(
              rawUrl,
              fit: BoxFit.cover,
              semanticLabel: publicSearchImage(tour.title, useEnglish),
              errorBuilder: (_, _, _) => const _NeutralThumbnailPlaceholder(),
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const _NeutralThumbnailPlaceholder();
              },
            )
          : const _NeutralThumbnailPlaceholder(),
    );
  }
}

class _NeutralThumbnailPlaceholder extends StatelessWidget {
  const _NeutralThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.surfaceElevated, c.canvas],
          ),
        ),
        child: Center(
          child: Icon(Icons.image_outlined, size: 34, color: c.textMuted),
        ),
      ),
    );
  }
}

class _MatchingScoreBadge extends StatelessWidget {
  const _MatchingScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final percentage = (score * 100).round();
    return Semantics(
      label: '$percentage% phù hợp',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.successContainer,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: c.success.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 13, color: c.success),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$percentage% phù hợp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
