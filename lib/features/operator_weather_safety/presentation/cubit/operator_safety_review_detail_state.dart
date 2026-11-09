import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';

enum OperatorSafetyReviewDetailStatus { loading, ready, notFound, failure }

final class OperatorSafetyReviewDetailState extends Equatable {
  const OperatorSafetyReviewDetailState({
    this.status = OperatorSafetyReviewDetailStatus.loading,
    this.review,
    this.failure,
    this.actionFailure,
    this.isAcknowledging = false,
    this.isStale = false,
    this.isOffline = false,
  });

  final OperatorSafetyReviewDetailStatus status;
  final WeatherSafetyReview? review;
  final Failure? failure;

  /// The last acknowledge attempt failed; the review stays visible.
  final Failure? actionFailure;
  final bool isAcknowledging;

  /// The review could not be refreshed and may be out of date.
  final bool isStale;

  /// No connection: acknowledging is unavailable until a reconnect refresh.
  final bool isOffline;

  OperatorSafetyReviewDetailState copyWith({
    Failure? actionFailure,
    bool clearActionFailure = false,
    bool? isAcknowledging,
    bool? isStale,
    bool? isOffline,
  }) => OperatorSafetyReviewDetailState(
    status: status,
    review: review,
    failure: failure,
    actionFailure: clearActionFailure
        ? null
        : actionFailure ?? this.actionFailure,
    isAcknowledging: isAcknowledging ?? this.isAcknowledging,
    isStale: isStale ?? this.isStale,
    isOffline: isOffline ?? this.isOffline,
  );

  @override
  List<Object?> get props => [
    status,
    review,
    failure,
    actionFailure,
    isAcknowledging,
    isStale,
    isOffline,
  ];
}
