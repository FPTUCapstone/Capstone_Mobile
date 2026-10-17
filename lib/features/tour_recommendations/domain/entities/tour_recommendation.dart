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

  /// Matching score between 0.0 and 1.0 (e.g. 0.92 for 92%).
  /// Must be > 0.80 per canonical matching threshold rule.
  final double matchingScore;

  /// Reasons explaining why this tour was matched with the traveler's preferences.
  final List<String> matchReasons;

  /// Returns matching score as an integer percentage (e.g. 92).
  int get scorePercentage => (matchingScore * 100).round();

  @override
  List<Object?> get props => [tour, matchingScore, matchReasons];
}
