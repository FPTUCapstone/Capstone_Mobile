import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// Presentation entity for Tour Discovery (SRS #44, #63, #64) mapping cleanly
/// to production [TourSummary].
class TourDiscoveryItem extends Equatable {
  const TourDiscoveryItem({
    required this.id,
    required this.title,
    String? destinations,
    List<String>? destinationsList,
    required this.operatorName,
    required this.durationDays,
    required this.priceVnd,
    this.currency = 'VND',
    this.representativeScheduleId,
    this.rating,
    this.imageUrl,
    this.availabilityStatus = AvailabilityStatus.available,
    this.remainingSlots,
    this.departureAtUtc,
    this.isCuratedAsset = false,
  }) : assert(
         destinations != null || destinationsList != null,
         'Either destinations or destinationsList must be provided.',
       ),
       _destinationsList = destinationsList,
       _destinationsString = destinations;

  factory TourDiscoveryItem.fromSummary(TourSummary summary) {
    return TourDiscoveryItem(
      id: summary.tourId,
      title: summary.title,
      destinationsList: summary.destinations,
      operatorName: summary.operatorName,
      durationDays: summary.durationDays,
      priceVnd: summary.basePrice,
      currency: summary.currency,
      representativeScheduleId: summary.representativeScheduleId,
      rating: summary.aggregateRating,
      imageUrl: summary.thumbnailUrl,
      availabilityStatus: summary.availabilityStatus,
      remainingSlots: summary.remainingSlots,
      departureAtUtc: summary.departureAtUtc,
      isCuratedAsset: false,
    );
  }

  final String id;
  final String title;
  final List<String>? _destinationsList;
  final String? _destinationsString;
  final String operatorName;
  final int durationDays;
  final int priceVnd;
  final String currency;
  final String? representativeScheduleId;
  final double? rating;
  final String? imageUrl;
  final AvailabilityStatus availabilityStatus;
  final int? remainingSlots;
  final DateTime? departureAtUtc;
  final bool isCuratedAsset;

  /// Derived display string joining canonical destinations with ' · '.
  String get destinations {
    if (_destinationsList != null) {
      return _destinationsList.join(' · ');
    }
    return _destinationsString ?? '';
  }

  /// Canonical ordered list of destinations.
  List<String> get destinationsList {
    if (_destinationsList != null) {
      return _destinationsList;
    }
    if (_destinationsString != null && _destinationsString.isNotEmpty) {
      return _destinationsString.split(' · ');
    }
    return const [];
  }

  TourSummary toSummary() {
    return TourSummary(
      tourId: id,
      title: title,
      destinations: destinationsList,
      operatorName: operatorName,
      durationDays: durationDays,
      basePrice: priceVnd,
      currency: currency,
      representativeScheduleId: representativeScheduleId,
      departureAtUtc: departureAtUtc,
      availabilityStatus: availabilityStatus,
      remainingSlots: remainingSlots,
      thumbnailUrl: imageUrl,
      aggregateRating: rating,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    destinationsList,
    operatorName,
    durationDays,
    priceVnd,
    currency,
    representativeScheduleId,
    rating,
    imageUrl,
    availabilityStatus,
    remainingSlots,
    departureAtUtc,
    isCuratedAsset,
  ];
}
