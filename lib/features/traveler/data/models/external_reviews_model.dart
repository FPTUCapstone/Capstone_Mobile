import 'package:trip_mate_mobile/features/traveler/data/models/json_readers.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/external_reviews.dart';

/// `GET /api/v1/pois/{id}/external-reviews` response.
final class PoiExternalReviewsModel {
  const PoiExternalReviewsModel(this._json);

  factory PoiExternalReviewsModel.fromJson(Map<String, dynamic> json) {
    if (json['poiId'] is! int || json['reviews'] is! List) {
      throw const FormatException('Invalid external reviews response.');
    }
    return PoiExternalReviewsModel(json);
  }

  final Map<String, dynamic> _json;

  PoiExternalReviews toEntity() => PoiExternalReviews(
    poiId: _json['poiId'] as int,
    translationAvailable: _json['translationAvailable'] == true,
    source: readString(_json['source']),
    rating: readDouble(_json['rating']),
    reviewCount: readInt(_json['reviewCount']) ?? 0,
    ratingImageUrl: readString(_json['ratingImageUrl']),
    url: readString(_json['url']),
    reviews: (_json['reviews'] as List)
        .whereType<Map>()
        .map(_review)
        .whereType<ExternalReview>()
        .toList(growable: false),
  );

  static ExternalReview? _review(Map json) {
    final id = readInt(json['id']);
    if (id == null) return null;
    final published = json['publishedAt'];
    return ExternalReview(
      id: id,
      rating: readInt(json['rating']) ?? 0,
      title: readString(json['title']),
      text: readString(json['text']),
      language: readString(json['language']),
      publishedAt: published is String
          ? DateTime.tryParse(published)?.toUtc()
          : null,
      travelDate: readString(json['travelDate']),
      author: readString(json['author']),
      url: readString(json['url']),
      ratingImageUrl: readString(json['ratingImageUrl']),
    );
  }
}

/// `GET .../external-reviews/{reviewId}/translation` response.
final class TranslatedReviewModel {
  const TranslatedReviewModel(this._json);

  factory TranslatedReviewModel.fromJson(Map<String, dynamic> json) {
    if (json['reviewId'] is! num) {
      throw const FormatException('Invalid review translation response.');
    }
    return TranslatedReviewModel(json);
  }

  final Map<String, dynamic> _json;

  TranslatedReview toEntity() => TranslatedReview(
    reviewId: (_json['reviewId'] as num).toInt(),
    title: readString(_json['title']),
    text: readString(_json['text']),
  );
}
