import 'package:equatable/equatable.dart';

final class TripReviewPhotoAttachment extends Equatable {
  const TripReviewPhotoAttachment({
    required this.name,
    required this.sizeBytes,
    this.path,
  });

  final String name;
  final int sizeBytes;
  final String? path;

  /// BR-16: An attached photo must be an image file whose size does not exceed 5 MB.
  static const int maxSizeBytes = 5 * 1024 * 1024; // 5 MB

  bool get isValidSize => sizeBytes <= maxSizeBytes && sizeBytes > 0;

  @override
  List<Object?> get props => [name, sizeBytes, path];
}

final class TripReviewSubmission extends Equatable {
  const TripReviewSubmission({
    required this.tripId,
    required this.bookingCode,
    required this.travelerId,
    required this.rating,
    required this.title,
    required this.content,
    this.photos = const <TripReviewPhotoAttachment>[],
    this.existingReviewId,
  });

  final String tripId;
  final String bookingCode;
  final int travelerId;
  final int rating; // 1 to 5
  final String title;
  final String content;
  final List<TripReviewPhotoAttachment> photos;
  final String? existingReviewId;

  bool get isEdit => existingReviewId != null;

  @override
  List<Object?> get props => [
    tripId,
    bookingCode,
    travelerId,
    rating,
    title,
    content,
    photos,
    existingReviewId,
  ];
}
