import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_suggestion_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_suggestions_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/external_reviews_sheet.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

/// Lets the traveler pick a restaurant to add ([SuggestionKind.food]) or a
/// replacement ([SuggestionKind.replace]). Places that would not fit are shown
/// greyed with the reason and cannot be chosen; places that only exceed the
/// itinerary end time by a known [ItinerarySuggestion.overflowMinutes] remain
/// selectable and ask for confirmation before extending the schedule.
Future<ItinerarySuggestion?> showItinerarySuggestionsSheet(
  BuildContext context, {
  required ItinerarySuggestionRepository repository,
  required int itineraryId,
  required SuggestionKind kind,
  required int itemId,
  ExternalReviewRepository? reviewRepository,
  String? Function(int poiId)? stopName,
  DateTime? currentEndTime,
  String? anchorName,
}) {
  final palette = CoastalPalette.of(context);
  return showModalBottomSheet<ItinerarySuggestion>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BlocProvider(
      create: (_) =>
          ItinerarySuggestionsCubit(repository: repository)
            ..load(itineraryId: itineraryId, kind: kind, itemId: itemId),
      child: _SuggestionsSheet(
        kind: kind,
        reviewRepository: reviewRepository,
        stopName: stopName,
        currentEndTime: currentEndTime,
        anchorName: anchorName,
      ),
    ),
  );
}

final class _SuggestionsSheet extends StatelessWidget {
  const _SuggestionsSheet({
    required this.kind,
    this.reviewRepository,
    this.stopName,
    this.currentEndTime,
    this.anchorName,
  });

  final SuggestionKind kind;
  final ExternalReviewRepository? reviewRepository;
  final String? Function(int poiId)? stopName;
  final DateTime? currentEndTime;
  final String? anchorName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = CoastalPalette.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind == SuggestionKind.food
                              ? 'Thêm quán ăn'
                              : 'Thay địa điểm',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Điểm vượt giờ kết thúc sẽ hỏi xác nhận trước khi '
                          'kéo dài lịch trình.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: palette.secondary, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Divider(height: 1, color: palette.border),
              Expanded(
                child:
                    BlocBuilder<
                      ItinerarySuggestionsCubit,
                      ItinerarySuggestionsState
                    >(
                      builder: (context, state) {
                        final suggestions = state.suggestions;
                        if (state.status == SuggestionsStatus.loading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (state.status == SuggestionsStatus.failure ||
                            suggestions == null) {
                          return Center(
                            child: Text(
                              state.message ?? 'Chưa tải được gợi ý.',
                            ),
                          );
                        }
                        if (suggestions.items.isEmpty) {
                          return _EmptySuggestions(
                            radiusKm: suggestions.searchRadiusKm,
                          );
                        }
                        return ListView.separated(
                          itemCount: suggestions.items.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: palette.border),
                          itemBuilder: (context, index) => _SuggestionTile(
                            suggestion: suggestions.items[index],
                            kind: kind,
                            reviewRepository: reviewRepository,
                            stopName: stopName,
                            currentEndTime: currentEndTime,
                            anchorName: anchorName,
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _EmptySuggestions extends StatelessWidget {
  const _EmptySuggestions({required this.radiusKm});

  final double radiusKm;

  @override
  Widget build(BuildContext context) {
    final radius = radiusKm == radiusKm.roundToDouble()
        ? radiusKm.toStringAsFixed(0)
        : radiusKm.toStringAsFixed(1).replaceAll('.', ',');
    return Center(
      key: const Key('suggestions_empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Không có điểm phù hợp trong $radius km'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mở rộng bán kính: tạo lịch trình mới với bán kính lớn hơn để có '
            'thêm lựa chọn.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

final class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.kind,
    this.reviewRepository,
    this.stopName,
    this.currentEndTime,
    this.anchorName,
  });

  final ItinerarySuggestion suggestion;
  final SuggestionKind kind;
  final ExternalReviewRepository? reviewRepository;
  final String? Function(int poiId)? stopName;
  final DateTime? currentEndTime;
  final String? anchorName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = CoastalPalette.of(context);
    final selectable = suggestion.isSelectable;
    final isOvertime = suggestion.isOvertimeExtension;
    final distance = _distanceText();
    final reasonText = (!selectable || isOvertime) ? _unfitText() : null;
    final rating = suggestion.tripadvisor;
    final reviews = reviewRepository;

    final tile = Opacity(
      opacity: selectable ? 1 : 0.5,
      child: InkWell(
        onTap: selectable ? () => _handleSelect(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    suggestion.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  if (selectable &&
                      !isOvertime &&
                      suggestion.fitsItinerary == true)
                    Text(
                      'Vừa lịch trình',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (isOvertime && reasonText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.warningBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        reasonText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.warningText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (suggestion.address case final address?
                  when address.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.secondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                visitPriceLabel(suggestion.estimatedCost, suggestion.costKind),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (distance != null)
                Text(
                  distance,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.secondary,
                  ),
                ),
              if (suggestion.closesAt case final closesAt?)
                Text(
                  'Đóng cửa lúc $closesAt',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.secondary,
                  ),
                ),
              if (suggestion.fitsItinerary == null)
                Text(
                  'Chưa kiểm tra được thời gian, sẽ kiểm tra khi lưu.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.secondary,
                  ),
                ),
              if (!selectable && reasonText != null) ...[
                const SizedBox(height: 2),
                Text(
                  reasonText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (rating != null)
                Row(
                  children: [
                    Flexible(
                      child: TripadvisorRatingRow(
                        rating: rating.rating,
                        reviewCount: rating.reviewCount,
                      ),
                    ),
                    // Hidden when Tripadvisor has no recent reviews to read.
                    if (reviews != null && rating.hasRecentReviews != false)
                      TextButton(
                        onPressed: () => showExternalReviewsSheet(
                          context,
                          repository: reviews,
                          poiId: suggestion.poiId,
                          poiName: suggestion.name,
                        ),
                        child: const Text('Xem đánh giá'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    if (selectable) return tile;
    // Read out as one disabled item with the reason it cannot be chosen.
    return Semantics(
      container: true,
      enabled: false,
      excludeSemantics: true,
      label: '${suggestion.name}. Không chọn được: $reasonText',
      child: tile,
    );
  }

  Future<void> _handleSelect(BuildContext context) async {
    if (!suggestion.isOvertimeExtension) {
      Navigator.of(context).pop(suggestion);
      return;
    }
    final overflow = suggestion.overflowMinutes!;
    final confirmed = await _confirmOvertimeExtension(context, overflow);
    if (confirmed && context.mounted) {
      Navigator.of(context).pop(suggestion);
    }
  }

  Future<bool> _confirmOvertimeExtension(
    BuildContext context,
    int overflowMinutes,
  ) async {
    final palette = CoastalPalette.of(context);
    final theme = Theme.of(context);
    final isFood = kind == SuggestionKind.food;
    final durationText = vietnameseDuration(overflowMinutes);
    final baseEnd = currentEndTime;
    final extendedEnd = baseEnd?.add(Duration(minutes: overflowMinutes));
    final anchor = anchorName?.trim();
    final hasAnchor = anchor != null && anchor.isNotEmpty;
    final actionVerb = isFood ? 'Thêm' : 'Thay bằng';
    final anchorPhrase = hasAnchor
        ? (isFood ? ' sau $anchor' : ' thay cho $anchor')
        : '';

    final cost = suggestion.estimatedCost;
    final costText = cost == null
        ? null
        : cost <= 0
        ? 'Miễn phí'
        : formatVnd(cost);
    final detailParts = [
      ?costText,
      if (suggestion.closesAt case final closes?) 'Đóng $closes',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          'Kéo dài lịch trình thêm $durationText?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$actionVerb ${suggestion.name}$anchorPhrase cần thêm thời gian '
              'di chuyển và dừng chân.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.secondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          baseEnd != null
                              ? 'Giờ kết thúc dự kiến'
                              : 'Thời gian kéo dài thêm',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.secondary,
                          ),
                        ),
                        if (baseEnd != null && extendedEnd != null)
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: tripClock(baseEnd),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.secondary,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                TextSpan(
                                  text: ' → ',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.secondary,
                                  ),
                                ),
                                TextSpan(
                                  text: tripClock(extendedEnd),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: palette.primary,
                                  ),
                                ),
                                TextSpan(
                                  text: ' (+$durationText)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: palette.warningText,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            '+$durationText',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: palette.warningText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 16, color: palette.border),
                  Text(
                    suggestion.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  if (detailParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detailParts.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.ink,
              side: BorderSide(color: palette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isFood ? 'Tiếp tục thêm quán' : 'Tiếp tục thay điểm'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String? _distanceText() {
    final meters = suggestion.distanceFromPreviousMeters;
    final detour = suggestion.detourMinutes;
    final parts = [
      if (meters != null)
        suggestion.isStraightLine
            ? '~${formatLegDistance(meters)} (đường chim bay)'
            : formatLegDistance(meters),
      if (detour != null)
        detour > 0
            ? 'dài thêm ${vietnameseDuration(detour)}'
            : detour < 0
            ? 'ngắn hơn ${vietnameseDuration(detour)}'
            : 'không dài thêm',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _unfitText() {
    if (suggestion.unfitReason == null && suggestion.openAtArrival == false) {
      return 'Đóng cửa khi đến nơi';
    }
    final reason = unfitReasonText(
      suggestion.unfitReason,
      closesAt: suggestion.closesAt,
      overflowMinutes: suggestion.overflowMinutes,
      overflowVnd: suggestion.overflowVnd,
    );
    final brokenStop = suggestion.unfitPoiId;
    if (brokenStop != null && brokenStop != suggestion.poiId) {
      final name = stopName?.call(brokenStop);
      if (name != null) return '$name: $reason';
    }
    return capitalized(reason);
  }
}
