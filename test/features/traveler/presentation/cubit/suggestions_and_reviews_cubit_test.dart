import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/external_reviews.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_suggestion_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/external_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_suggestions_cubit.dart';

void main() {
  group('ItinerarySuggestionsCubit', () {
    test('loads suggestions for the chosen stop', () async {
      final repository = FakeSuggestionRepository(
        const ItinerarySuggestions(
          itineraryId: 10,
          kind: SuggestionKind.food,
          searchRadiusKm: 15,
          items: [ItinerarySuggestion(poiId: 1, name: 'Bún')],
        ),
      );
      final cubit = ItinerarySuggestionsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load(itineraryId: 10, kind: SuggestionKind.food, itemId: 7);

      expect(repository.requests, [(10, SuggestionKind.food, 7)]);
      expect(cubit.state.status, SuggestionsStatus.loaded);
      expect(cubit.state.suggestions?.items.single.name, 'Bún');
    });

    test('a failure is shown without technical details', () async {
      final repository = FakeSuggestionRepository(
        null,
        failure: const NetworkFailure(),
      );
      final cubit = ItinerarySuggestionsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load(
        itineraryId: 10,
        kind: SuggestionKind.replace,
        itemId: 7,
      );

      expect(cubit.state.status, SuggestionsStatus.failure);
      expect(cubit.state.message, 'Chưa tải được gợi ý. Vui lòng thử lại.');
    });
  });

  group('ExternalReviewsCubit', () {
    test('loads reviews, then translates one on demand and back', () async {
      final repository = FakeReviewRepository(reviewsFixture());
      final cubit = ExternalReviewsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load(501);
      expect(cubit.state.status, ExternalReviewsStatus.loaded);
      expect(cubit.state.reviews?.reviews, hasLength(1));

      await cubit.toggleTranslation(9001);
      expect(cubit.state.translationOf(9001)?.text, 'Rất ngon');
      expect(cubit.state.isShowingTranslation(9001), isTrue);

      await cubit.toggleTranslation(9001);
      expect(cubit.state.isShowingTranslation(9001), isFalse);
      // The translation is kept: showing it again needs no new request.
      await cubit.toggleTranslation(9001);
      expect(repository.translated, [9001]);
    });

    test('a failed translation keeps the original', () async {
      final repository = FakeReviewRepository(
        reviewsFixture(),
        translationFailure: const ServerFailure(),
      );
      final cubit = ExternalReviewsCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load(501);

      await cubit.toggleTranslation(9001);

      expect(cubit.state.isShowingTranslation(9001), isFalse);
      expect(cubit.state.translationFailed(9001), isTrue);
    });
  });
}

PoiExternalReviews reviewsFixture({
  String? source = 'Tripadvisor',
  bool translationAvailable = true,
  List<ExternalReview> reviews = const [
    ExternalReview(
      id: 9001,
      rating: 5,
      title: 'Great noodles',
      text: 'Loved it',
      language: 'en',
      author: 'Anna',
      ratingImageUrl: 'https://static.tacdn.com/img/5.0.svg',
    ),
  ],
}) => PoiExternalReviews(
  poiId: 501,
  translationAvailable: translationAvailable,
  source: source,
  rating: 4.5,
  reviewCount: 310,
  ratingImageUrl: 'https://static.tacdn.com/img/4.5.svg',
  url: 'https://www.tripadvisor.com/x',
  reviews: reviews,
);

final class FakeSuggestionRepository implements ItinerarySuggestionRepository {
  FakeSuggestionRepository(this.result, {this.failure});

  final ItinerarySuggestions? result;
  final Failure? failure;
  final requests = <(int, SuggestionKind, int)>[];

  @override
  Future<ItinerarySuggestions> getSuggestions({
    required int itineraryId,
    required SuggestionKind kind,
    required int itemId,
  }) async {
    requests.add((itineraryId, kind, itemId));
    if (failure case final failure?) throw failure;
    return result!;
  }
}

final class FakeReviewRepository implements ExternalReviewRepository {
  FakeReviewRepository(this.reviews, {this.translationFailure});

  final PoiExternalReviews reviews;
  final Failure? translationFailure;
  final translated = <int>[];

  @override
  Future<PoiExternalReviews> getReviews(int poiId, {int size = 5}) async =>
      reviews;

  @override
  Future<TranslatedReview> translate({
    required int poiId,
    required int reviewId,
  }) async {
    translated.add(reviewId);
    if (translationFailure case final failure?) throw failure;
    return TranslatedReview(
      reviewId: reviewId,
      title: 'Bún ngon',
      text: 'Rất ngon',
    );
  }
}
