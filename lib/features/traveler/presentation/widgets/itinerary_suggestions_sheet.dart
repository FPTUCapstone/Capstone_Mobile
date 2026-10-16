import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_suggestion_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_suggestions_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/external_reviews_sheet.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

/// Lets the traveler pick a restaurant to add ([SuggestionKind.food]) or a
/// replacement ([SuggestionKind.replace]). Places that would not fit are shown
/// greyed with the reason and cannot be chosen. [stopName] names current stops
/// (a suggestion may push a later stop past its closing time).
Future<ItinerarySuggestion?> showItinerarySuggestionsSheet(
  BuildContext context, {
  required ItinerarySuggestionRepository repository,
  required int itineraryId,
  required SuggestionKind kind,
  required int itemId,
  ExternalReviewRepository? reviewRepository,
  String? Function(int poiId)? stopName,
}) => showModalBottomSheet<ItinerarySuggestion>(
  context: context,
  isScrollControlled: true,
  builder: (_) => BlocProvider(
    create: (_) =>
        ItinerarySuggestionsCubit(repository: repository)
          ..load(itineraryId: itineraryId, kind: kind, itemId: itemId),
    child: _SuggestionsSheet(
      kind: kind,
      reviewRepository: reviewRepository,
      stopName: stopName,
    ),
  ),
);

final class _SuggestionsSheet extends StatelessWidget {
  const _SuggestionsSheet({
    required this.kind,
    this.reviewRepository,
    this.stopName,
  });

  final SuggestionKind kind;
  final ExternalReviewRepository? reviewRepository;
  final String? Function(int poiId)? stopName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kind == SuggestionKind.food ? 'Thêm quán ăn' : 'Thay địa điểm',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chỉ chọn được những nơi vẫn giữ lịch trình hợp lệ.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
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
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) => _SuggestionTile(
                            suggestion: suggestions.items[index],
                            reviewRepository: reviewRepository,
                            stopName: stopName,
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
    this.reviewRepository,
    this.stopName,
  });

  final ItinerarySuggestion suggestion;
  final ExternalReviewRepository? reviewRepository;
  final String? Function(int poiId)? stopName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectable = suggestion.isSelectable;
    final distance = _distanceText();
    final unfit = selectable ? null : _unfitText();
    final rating = suggestion.tripadvisor;
    final reviews = reviewRepository;
    final tile = Opacity(
      opacity: selectable ? 1 : 0.5,
      child: InkWell(
        onTap: selectable ? () => Navigator.of(context).pop(suggestion) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(suggestion.name, style: theme.textTheme.titleSmall),
              Text(
                visitPriceLabel(suggestion.estimatedCost, suggestion.costKind),
                style: theme.textTheme.bodySmall,
              ),
              if (distance != null)
                Text(distance, style: theme.textTheme.bodySmall),
              if (suggestion.closesAt case final closesAt?)
                Text(
                  'Đóng cửa lúc $closesAt',
                  style: theme.textTheme.bodySmall,
                ),
              if (suggestion.fitsItinerary == null)
                Text(
                  'Chưa kiểm tra được thời gian, sẽ kiểm tra khi lưu.',
                  style: theme.textTheme.bodySmall,
                ),
              if (unfit != null)
                Text(
                  unfit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
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
      label: '${suggestion.name}. Không chọn được: $unfit',
      child: tile,
    );
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
