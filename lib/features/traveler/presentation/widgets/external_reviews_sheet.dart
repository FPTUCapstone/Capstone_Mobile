import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/external_reviews.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/external_reviews_cubit.dart';

/// Tripadvisor reviews of one place, loaded after the sheet opens.
Future<void> showExternalReviewsSheet(
  BuildContext context, {
  required ExternalReviewRepository repository,
  required int poiId,
  required String poiName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => BlocProvider(
    create: (_) => ExternalReviewsCubit(repository: repository)..load(poiId),
    child: _ExternalReviewsSheet(poiName: poiName),
  ),
);

/// A Tripadvisor score as plain text with a Vietnamese decimal comma: "4,2/5",
/// and "5/5" for a whole score.
String tripadvisorScoreText(num rating) {
  final fixed = rating.toStringAsFixed(1);
  final score = fixed.endsWith('.0')
      ? fixed.substring(0, fixed.length - 2)
      : fixed.replaceAll('.', ',');
  return '$score/5';
}

/// Tripadvisor attribution as plain text only: "Tripadvisor · 4,2/5 · 717
/// đánh giá", or "Tripadvisor · 717 đánh giá" without a rating. No
/// Tripadvisor image or logo is shown (the API's rating image is not
/// rendered), and it is never a link: nothing here leaves TripMate.
final class TripadvisorRatingRow extends StatelessWidget {
  const TripadvisorRatingRow({
    required this.reviewCount,
    this.rating,
    super.key,
  });

  final double? rating;
  final int reviewCount;

  /// The visible text, also read out as one label.
  String get semanticsLabel {
    final rating = this.rating;
    return [
      if (rating != null) tripadvisorScoreText(rating),
      '${_grouped(reviewCount)} đánh giá',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Text(
        semanticsLabel,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    final offset = digits.length % 3;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (i - offset) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

final class _ExternalReviewsSheet extends StatelessWidget {
  const _ExternalReviewsSheet({required this.poiName});

  final String poiName;

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
                'Đánh giá · $poiName',
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: BlocBuilder<ExternalReviewsCubit, ExternalReviewsState>(
                  builder: (context, state) => switch (state.status) {
                    ExternalReviewsStatus.loading => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    ExternalReviewsStatus.failure => const Center(
                      child: Text('Chưa tải được đánh giá. Vui lòng thử lại.'),
                    ),
                    ExternalReviewsStatus.loaded => _ReviewsBody(state: state),
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

final class _ReviewsBody extends StatelessWidget {
  const _ReviewsBody({required this.state});

  final ExternalReviewsState state;

  @override
  Widget build(BuildContext context) {
    final reviews = state.reviews;
    if (reviews == null || !reviews.isAvailable) {
      return const Center(child: Text('Chưa có đánh giá cho địa điểm này.'));
    }
    final rating = TripadvisorRatingRow(
      rating: reviews.rating,
      reviewCount: reviews.reviewCount,
    );
    // Tripadvisor serves only recent reviews: a rated place can have none.
    if (reviews.reviews.isEmpty) {
      return ListView(
        children: [
          rating,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('Chưa có đánh giá gần đây để hiển thị.'),
          ),
        ],
      );
    }
    return ListView(
      children: [
        rating,
        const Divider(),
        for (final review in reviews.reviews)
          _ReviewTile(
            review: review,
            translationAvailable: reviews.translationAvailable,
            state: state,
          ),
      ],
    );
  }
}

final class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.translationAvailable,
    required this.state,
  });

  final ExternalReview review;
  final bool translationAvailable;
  final ExternalReviewsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTranslation = state.isShowingTranslation(review.id);
    final translation = state.translationOf(review.id);
    final title = showTranslation ? translation?.title : review.title;
    final text = showTranslation ? translation?.text : review.text;
    final byline = [
      if (review.author != null) review.author!,
      if (review.travelDate != null) review.travelDate!,
    ].join(' · ');
    final cubit = context.read<ExternalReviewsCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tripadvisorScoreText(review.rating),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (title != null && title.isNotEmpty)
            Text(title, style: theme.textTheme.titleSmall),
          if (text != null && text.isNotEmpty) Text(text),
          if (byline.isNotEmpty)
            Text(
              byline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (translationAvailable)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: state.isTranslating(review.id)
                      ? null
                      : () => cubit.toggleTranslation(review.id),
                  child: Text(
                    showTranslation
                        ? 'Bản dịch tự động · Xem bản gốc'
                        : 'Dịch sang tiếng Việt',
                  ),
                ),
                if (state.isTranslating(review.id))
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (state.translationFailed(review.id))
                  Text(
                    'Chưa dịch được.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
