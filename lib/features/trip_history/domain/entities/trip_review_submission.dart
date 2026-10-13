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

  /// Verified Backend contract: each image may contain at most 5,000,000 bytes.
  static const int maxSizeBytes = 5_000_000;

  /// Supported image extensions for Demo validation (aligning with provisional backend direction).
  static const supportedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  bool get isValidType {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return false;
    final ext = name.substring(dotIndex + 1).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  bool get isValidSize => sizeBytes <= maxSizeBytes && sizeBytes > 0;

  bool get isValid => isValidType && isValidSize;

  @override
  List<Object?> get props => [name, sizeBytes, path];
}

final class TripReviewSubmission extends Equatable {
  const TripReviewSubmission({
    required this.tripId,
    required this.bookingCode,
    this.travelerId,
    required this.rating,
    required this.title,
    required this.content,
    this.photos = const <TripReviewPhotoAttachment>[],
    this.existingReviewId,
  });

  final String tripId;
  final String bookingCode;

  /// Optional in Production (Backend derives owner identity from authenticated token).
  /// Populated in Demo mode for tenant isolation tests only.
  final int? travelerId;
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
