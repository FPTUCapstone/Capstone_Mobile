import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';

enum OperatorSafetyReviewsStatus { initial, loading, ready, failure }

final class OperatorSafetyReviewsState extends Equatable {
  const OperatorSafetyReviewsState({
    this.status = OperatorSafetyReviewsStatus.initial,
    this.reviews = const [],
    this.filter,
    this.failure,
    this.isStale = false,
  });

  final OperatorSafetyReviewsStatus status;

  /// Every owned review, in Backend order; the badge is computed from this.
  final List<WeatherSafetyReview> reviews;

  /// Null shows every status.
  final WeatherSafetyReviewStatus? filter;
  final Failure? failure;

  /// The list could not be refreshed and may be out of date.
  final bool isStale;

  List<WeatherSafetyReview> get visibleReviews => filter == null
      ? reviews
      : reviews.where((review) => review.status == filter).toList();

  int get badgeCount => reviews.where((review) => review.needsAttention).length;

  OperatorSafetyReviewsState copyWith({
    OperatorSafetyReviewsStatus? status,
    List<WeatherSafetyReview>? reviews,
    WeatherSafetyReviewStatus? filter,
    bool clearFilter = false,
    Failure? failure,
    bool clearFailure = false,
    bool? isStale,
  }) => OperatorSafetyReviewsState(
    status: status ?? this.status,
    reviews: reviews ?? this.reviews,
    filter: clearFilter ? null : filter ?? this.filter,
    failure: clearFailure ? null : failure ?? this.failure,
    isStale: isStale ?? this.isStale,
  );

  @override
  List<Object?> get props => [status, reviews, filter, failure, isStale];
}
