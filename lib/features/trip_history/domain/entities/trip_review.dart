import 'package:equatable/equatable.dart';

final class TripReview extends Equatable {
  const TripReview({
    required this.id,
    required this.tripId,
    required this.travelerId,
    required this.rating,
    required this.title,
    required this.content,
    this.photoUrls = const <String>[],
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tripId;
  final int travelerId;
  final int rating; // 1 to 5
  final String title;
  final String content;
  final List<String> photoUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// BR-95: A published review may be edited by its author within seven days
  /// after its submission; after that period it becomes read-only.
  bool isEditable([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays < 7 && !difference.isNegative;
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    travelerId,
    rating,
    title,
    content,
    photoUrls,
    createdAt,
    updatedAt,
  ];
}
