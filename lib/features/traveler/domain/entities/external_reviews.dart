import 'package:equatable/equatable.dart';

/// Tripadvisor rating and recent reviews of a place. [source] is null when the
/// place is not linked or Tripadvisor is switched off: the block is hidden.
final class PoiExternalReviews extends Equatable {
  const PoiExternalReviews({
    required this.poiId,
    required this.translationAvailable,
    required this.reviewCount,
    required this.reviews,
    this.source,
    this.rating,
    this.ratingImageUrl,
    this.url,
  });

  final int poiId;
  final bool translationAvailable;
  final String? source;
  final double? rating;
  final int reviewCount;
  final String? ratingImageUrl;
  final String? url;
  final List<ExternalReview> reviews;

  bool get isAvailable => source != null;

  @override
  List<Object?> get props => [
    poiId,
    translationAvailable,
    source,
    rating,
    reviewCount,
    ratingImageUrl,
    url,
    reviews,
  ];
}

final class ExternalReview extends Equatable {
  const ExternalReview({
    required this.id,
    required this.rating,
    this.title,
    this.text,
    this.language,
    this.publishedAt,
    this.travelDate,
    this.author,
    this.url,
    this.ratingImageUrl,
  });

  final int id;
  final int rating;
  final String? title;
  final String? text;
  final String? language;
  final DateTime? publishedAt;
  final String? travelDate;
  final String? author;
  final String? url;
  final String? ratingImageUrl;

  @override
  List<Object?> get props => [
    id,
    rating,
    title,
    text,
    language,
    publishedAt,
    travelDate,
    author,
    url,
    ratingImageUrl,
  ];
}

/// A machine translation of one review; the original is kept and shown first.
final class TranslatedReview extends Equatable {
  const TranslatedReview({required this.reviewId, this.title, this.text});

  final int reviewId;
  final String? title;
  final String? text;

  @override
  List<Object?> get props => [reviewId, title, text];
}
