import 'package:equatable/equatable.dart';

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
