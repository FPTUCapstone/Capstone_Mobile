import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

/// One itinerary in the Traveler's trip list: the current version they own or
/// share through a travel group.
final class ItinerarySummary extends Equatable {
  const ItinerarySummary({
    required this.itineraryId,
    required this.title,
    required this.version,
    required this.status,
    required this.validFrom,
    required this.validTo,
    required this.canManage,
    required this.stopCount,
    required this.openNavigationSessionId,
    this.transportMode,
    this.previewStopNames = const [],
  });

  final int itineraryId;
  final String? title;
  final int version;
  final String status;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool canManage;
  final int stopCount;

  /// The Traveler's unfinished navigation session on this trip, if any.
  final int? openNavigationSessionId;

  /// Primary transport mode for the trip, when sent by the backend.
  final TransportMode? transportMode;

  /// Up to the first few visit stop names for scannable titles and route previews.
  final List<String> previewStopNames;

  bool get isTripInProgress => openNavigationSessionId != null;

  @override
  List<Object?> get props => [
    itineraryId,
    title,
    version,
    status,
    validFrom,
    validTo,
    canManage,
    stopCount,
    openNavigationSessionId,
    transportMode,
    previewStopNames,
  ];
}

final class ItinerarySummaryPage extends Equatable {
  const ItinerarySummaryPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<ItinerarySummary> items;
  final int page;
  final int pageSize;
  final int totalCount;

  @override
  List<Object> get props => [items, page, pageSize, totalCount];
}
