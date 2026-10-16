import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/external_reviews.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';

enum ExternalReviewsStatus { loading, loaded, failure }

final class ExternalReviewsState extends Equatable {
  const ExternalReviewsState({
    this.status = ExternalReviewsStatus.loading,
    this.reviews,
    this.translations = const {},
    this.shownTranslations = const {},
    this.translating = const {},
    this.failedTranslations = const {},
  });

  final ExternalReviewsStatus status;
  final PoiExternalReviews? reviews;
  final Map<int, TranslatedReview> translations;
  final Set<int> shownTranslations;
  final Set<int> translating;
  final Set<int> failedTranslations;

  TranslatedReview? translationOf(int reviewId) => translations[reviewId];

  bool isShowingTranslation(int reviewId) =>
      shownTranslations.contains(reviewId);

  bool isTranslating(int reviewId) => translating.contains(reviewId);

  bool translationFailed(int reviewId) => failedTranslations.contains(reviewId);

  ExternalReviewsState copyWith({
    ExternalReviewsStatus? status,
    PoiExternalReviews? reviews,
    Map<int, TranslatedReview>? translations,
    Set<int>? shownTranslations,
    Set<int>? translating,
    Set<int>? failedTranslations,
  }) => ExternalReviewsState(
    status: status ?? this.status,
    reviews: reviews ?? this.reviews,
    translations: translations ?? this.translations,
    shownTranslations: shownTranslations ?? this.shownTranslations,
    translating: translating ?? this.translating,
    failedTranslations: failedTranslations ?? this.failedTranslations,
  );

  @override
  List<Object?> get props => [
    status,
    reviews,
    translations,
    shownTranslations,
    translating,
    failedTranslations,
  ];
}

/// Tripadvisor reviews of one place, with on-demand Vietnamese translation.
final class ExternalReviewsCubit extends Cubit<ExternalReviewsState> {
  ExternalReviewsCubit({required ExternalReviewRepository repository})
    : _repository = repository,
      super(const ExternalReviewsState());

  final ExternalReviewRepository _repository;
  int? _poiId;

  Future<void> load(int poiId) async {
    _poiId = poiId;
    emit(const ExternalReviewsState());
    try {
      final reviews = await _repository.getReviews(poiId);
      if (isClosed) return;
      emit(
        ExternalReviewsState(
          status: ExternalReviewsStatus.loaded,
          reviews: reviews,
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(const ExternalReviewsState(status: ExternalReviewsStatus.failure));
      }
    }
  }

  /// Shows the translation of [reviewId] (fetching it once), or the original
  /// again when the translation is showing.
  Future<void> toggleTranslation(int reviewId) async {
    final poiId = _poiId;
    if (poiId == null || state.isTranslating(reviewId)) return;
    if (state.isShowingTranslation(reviewId)) {
      emit(
        state.copyWith(
          shownTranslations: {...state.shownTranslations}..remove(reviewId),
        ),
      );
      return;
    }
    if (state.translations.containsKey(reviewId)) {
      emit(
        state.copyWith(
          shownTranslations: {...state.shownTranslations, reviewId},
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        translating: {...state.translating, reviewId},
        failedTranslations: {...state.failedTranslations}..remove(reviewId),
      ),
    );
    try {
      final translated = await _repository.translate(
        poiId: poiId,
        reviewId: reviewId,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          translations: {...state.translations, reviewId: translated},
          shownTranslations: {...state.shownTranslations, reviewId},
          translating: {...state.translating}..remove(reviewId),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          translating: {...state.translating}..remove(reviewId),
          failedTranslations: {...state.failedTranslations, reviewId},
        ),
      );
    }
  }
}
