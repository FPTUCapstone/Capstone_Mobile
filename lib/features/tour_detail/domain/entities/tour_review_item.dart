import 'package:equatable/equatable.dart';

/// Represents a published user review for a tour.
final class TourReviewItem extends Equatable {
  const TourReviewItem({
    required this.reviewId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.rating,
    required this.comment,
    required this.createdAtUtc,
  });

  final String reviewId;
  final String authorName;
  final String? authorAvatarUrl;
  final double rating;
  final String comment;
  final DateTime createdAtUtc;

  @override
  List<Object?> get props => [
    reviewId,
    authorName,
    authorAvatarUrl,
    rating,
    comment,
    createdAtUtc,
  ];
}
