import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// Immutable domain entity representing a recommended tour package (UC-25).
///
/// Contains the underlying [tour] summary along with the personalized [matchingScore]
/// and matching reasons derived from the Traveler's preferences.
final class TourRecommendation extends Equatable {
  const TourRecommendation({
    required this.tour,
    required this.matchingScore,
    this.matchReasons = const [],
  });

  /// The underlying tour summary.
  final TourSummary tour;

  /// Persisted Backend score on the 0–100 scale (e.g. 80.01).
  /// Must be strictly greater than 80.00.
  final double matchingScore;

  /// Reasons explaining why this tour was matched with the traveler's preferences.
  final List<String> matchReasons;

  /// Returns matching score as an integer percentage (e.g. 92).
  String get scorePercentage =>
      matchingScore.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');

  @override
  List<Object?> get props => [tour, matchingScore, matchReasons];
}
