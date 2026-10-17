import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';

/// `Food`: restaurants to add after a stop. `Replace`: places of the same
/// category to swap in for a stop.
enum SuggestionKind { food, replace }

final class ItinerarySuggestions extends Equatable {
  const ItinerarySuggestions({
    required this.itineraryId,
    required this.kind,
    required this.searchRadiusKm,
    required this.items,
  });

  final int itineraryId;
  final SuggestionKind kind;
  final double searchRadiusKm;
  final List<ItinerarySuggestion> items;

  @override
  List<Object?> get props => [itineraryId, kind, searchRadiusKm, items];
}

/// A place the traveler could add or swap in, already checked (not saved)
/// against the itinerary's time window, budget and opening hours.
final class ItinerarySuggestion extends Equatable {
  const ItinerarySuggestion({
    required this.poiId,
    required this.name,
    this.category,
    this.thumbnailUrl,
    this.address,
    this.costKind,
    this.estimatedCost,
    this.distanceFromPreviousMeters,
    this.detourMinutes,
    this.isStraightLine = false,
    this.estimatedArrival,
    this.openAtArrival,
    this.closesAt,
    this.fitsItinerary,
    this.unfitReason,
    this.unfitPoiId,
    this.overflowMinutes,
    this.overflowVnd,
    this.tripadvisor,
  });

  final int poiId;
  final String name;
  final String? category;
  final String? thumbnailUrl;
  final String? address;
  final CostKind? costKind;
  final double? estimatedCost;
  final int? distanceFromPreviousMeters;

  /// How much longer the whole trip becomes (negative when shorter).
  final int? detourMinutes;

  /// Distance is straight-line because routing was unavailable.
  final bool isStraightLine;
  final DateTime? estimatedArrival;
  final bool? openAtArrival;

  /// "HH:mm" local closing time.
  final String? closesAt;

  /// Null when routing was down and the fit is unknown.
  final bool? fitsItinerary;
  final String? unfitReason;

  /// The stop that breaks: this place, or a later stop it pushes past closing.
  final int? unfitPoiId;
  final int? overflowMinutes;
  final double? overflowVnd;
  final TripadvisorRating? tripadvisor;

  /// Places that do not fit or are closed on arrival are shown but cannot be
  /// chosen; an unknown fit can (the save re-checks it).
  bool get isSelectable => fitsItinerary != false && openAtArrival != false;

  @override
  List<Object?> get props => [
    poiId,
    name,
    category,
    thumbnailUrl,
    address,
    costKind,
    estimatedCost,
    distanceFromPreviousMeters,
    detourMinutes,
    isStraightLine,
    estimatedArrival,
    openAtArrival,
    closesAt,
    fitsItinerary,
    unfitReason,
    unfitPoiId,
    overflowMinutes,
    overflowVnd,
    tripadvisor,
  ];
}

/// Aggregate Tripadvisor rating, shown as plain text (the rating image is not
/// rendered).
final class TripadvisorRating extends Equatable {
  const TripadvisorRating({
    required this.locationId,
    required this.reviewCount,
    this.rating,
    this.ratingImageUrl,
    this.url,
    this.hasRecentReviews,
  });

  final int locationId;
  final double? rating;
  final int reviewCount;
  final String? ratingImageUrl;
  final String? url;

  /// Tripadvisor serves only recent reviews, so a rated place can have none
  /// to read. `false`: none; `true`: some; null: not checked.
  final bool? hasRecentReviews;

  @override
  List<Object?> get props => [
    locationId,
    rating,
    reviewCount,
    ratingImageUrl,
    url,
    hasRecentReviews,
  ];
}
