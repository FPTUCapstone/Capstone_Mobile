import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/external_reviews_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_suggestions_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';

Map<String, Object?> suggestionJson({
  int poiId = 501,
  String name = 'Bún chả cá Bà Lữ',
  bool? fits = true,
  bool? open = true,
  String? unfitReason,
  int? unfitPoiId,
  Map<String, Object?>? tripadvisor,
}) => {
  'poiId': poiId,
  'name': name,
  'category': 'Food & Drink',
  'thumbnailUrl': null,
  'address': '319 Hùng Vương',
  'costKind': 'AverageSpend',
  'estimatedCost': 45000,
  'distanceFromPreviousMeters': 1200,
  'detourMinutes': 12,
  'distanceSource': 'Road',
  'estimatedArrival': '2026-10-18T05:10:00+00:00',
  'openAtArrival': open,
  'closesAt': '21:00',
  'fitsItinerary': fits,
  'unfitReason': unfitReason,
  'unfitPoiId': unfitPoiId,
  'overflowMinutes': null,
  'overflowVnd': null,
  'tripadvisor': tripadvisor,
};

void main() {
  test('parses suggestions with fit check and Tripadvisor rating', () {
    final result = ItinerarySuggestionsModel.fromJson({
      'itineraryId': 10,
      'kind': 'Food',
      'searchRadiusKm': 15,
      'items': [
        suggestionJson(
          tripadvisor: {
            'locationId': 123,
            'rating': 4.5,
            'reviewCount': 310,
            'ratingImageUrl': 'https://static.tacdn.com/img/4.5.svg',
            'url': 'https://www.tripadvisor.com/x',
          },
        ),
        {
          ...suggestionJson(
            poiId: 502,
            fits: false,
            open: false,
            unfitReason: 'ClosedAtArrival',
            unfitPoiId: 502,
          ),
          'distanceSource': 'StraightLine',
          'overflowMinutes': 15,
          'overflowVnd': 20000.5,
        },
      ],
    }).toEntity();

    expect(result.kind, SuggestionKind.food);
    expect(result.searchRadiusKm, 15);
    final first = result.items.first;
    expect(first.costKind, CostKind.averageSpend);
    expect(first.estimatedCost, 45000);
    expect(first.detourMinutes, 12);
    expect(first.isStraightLine, isFalse);
    expect(first.estimatedArrival, DateTime.utc(2026, 10, 18, 5, 10));
    expect(first.isSelectable, isTrue);
    expect(first.tripadvisor?.rating, 4.5);
    expect(first.tripadvisor?.reviewCount, 310);
    final closed = result.items.last;
    expect(closed.isSelectable, isFalse);
    expect(closed.isStraightLine, isTrue);
    expect(closed.unfitReason, 'ClosedAtArrival');
    expect(closed.overflowMinutes, 15);
    expect(closed.overflowVnd, 20000.5);
    expect(closed.tripadvisor, isNull);
  });

  test('reads whether Tripadvisor has recent reviews to show', () {
    Map<String, Object?> rating([Map<String, Object?> extra = const {}]) => {
      'locationId': 123,
      'rating': 4.0,
      'reviewCount': 19,
      ...extra,
    };
    final items = ItinerarySuggestionsModel.fromJson({
      'itineraryId': 10,
      'kind': 'Food',
      'searchRadiusKm': 15,
      'items': [
        suggestionJson(tripadvisor: rating({'hasRecentReviews': true})),
        suggestionJson(tripadvisor: rating({'hasRecentReviews': false})),
        suggestionJson(tripadvisor: rating({'hasRecentReviews': null})),
        // An older payload without the field still parses.
        suggestionJson(tripadvisor: rating()),
      ],
    }).toEntity().items;

    expect(items.map((item) => item.tripadvisor?.hasRecentReviews), [
      true,
      false,
      null,
      null,
    ]);
    expect(items[1].tripadvisor?.reviewCount, 19);
  });

  test('unknown fit (routing down) stays selectable', () {
    final result = ItinerarySuggestionsModel.fromJson({
      'itineraryId': 10,
      'kind': 'Replace',
      'searchRadiusKm': 10.5,
      'items': [suggestionJson(fits: null, open: null)],
    }).toEntity();

    expect(result.kind, SuggestionKind.replace);
    expect(result.items.single.fitsItinerary, isNull);
    expect(result.items.single.isSelectable, isTrue);
  });

  test('rejects a malformed response', () {
    expect(
      () => ItinerarySuggestionsModel.fromJson({'items': 'x'}).toEntity(),
      throwsFormatException,
    );
  });

  test('parses external reviews and hides them without a source', () {
    final reviews = PoiExternalReviewsModel.fromJson({
      'poiId': 501,
      'translationAvailable': true,
      'source': 'Tripadvisor',
      'rating': 4.5,
      'reviewCount': 310,
      'ratingImageUrl': 'https://static.tacdn.com/img/4.5.svg',
      'url': 'https://www.tripadvisor.com/x',
      'reviews': [
        {
          'id': 9001,
          'rating': 5,
          'title': 'Great noodles',
          'text': 'Loved it',
          'language': 'en',
          'publishedAt': '2026-09-01T00:00:00Z',
          'travelDate': '2026-08',
          'author': 'Anna',
          'url': 'https://www.tripadvisor.com/r',
          'ratingImageUrl': 'https://static.tacdn.com/img/5.svg',
        },
      ],
    }).toEntity();

    expect(reviews.isAvailable, isTrue);
    expect(reviews.translationAvailable, isTrue);
    expect(reviews.reviews.single.title, 'Great noodles');
    expect(reviews.reviews.single.language, 'en');

    final hidden = PoiExternalReviewsModel.fromJson({
      'poiId': 7,
      'translationAvailable': false,
      'source': null,
      'rating': null,
      'reviewCount': 0,
      'ratingImageUrl': null,
      'url': null,
      'reviews': <Object>[],
    }).toEntity();
    expect(hidden.isAvailable, isFalse);
  });

  test('parses a translated review', () {
    final translated = TranslatedReviewModel.fromJson({
      'reviewId': 9001,
      'language': 'vi',
      'title': 'Bún ngon',
      'text': 'Rất thích',
      'machineTranslated': true,
    }).toEntity();

    expect(translated.reviewId, 9001);
    expect(translated.text, 'Rất thích');
  });
}
