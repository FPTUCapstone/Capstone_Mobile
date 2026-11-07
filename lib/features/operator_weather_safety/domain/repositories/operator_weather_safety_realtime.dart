import 'package:equatable/equatable.dart';

/// A refresh hint for the Operator's reviews. It is never business truth: the
/// inbox always re-reads REST when one arrives.
final class WeatherSafetyReviewHint extends Equatable {
  const WeatherSafetyReviewHint({
    required this.reviewId,
    required this.changeType,
    required this.occurredAtUtc,
  });

  final int reviewId;

  /// Backend text: `Created`, `Updated`, `Escalated` or `Closed`.
  final String changeType;
  final DateTime occurredAtUtc;

  @override
  List<Object?> get props => [reviewId, changeType, occurredAtUtc];
}

abstract interface class OperatorWeatherSafetyRealtime {
  Stream<WeatherSafetyReviewHint> get hints;

  /// Emits whether the connection is currently up.
  Stream<bool> get connection;

  Future<void> start();

  Future<void> stop();
}
