import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';

enum MyTripsStatus { initial, loading, ready, failure }

final class MyTripsState extends Equatable {
  const MyTripsState({
    this.status = MyTripsStatus.initial,
    this.trips = const [],
    this.totalCount = 0,
    this.isLoadingMore = false,
    this.message,
  });

  final MyTripsStatus status;
  final List<ItinerarySummary> trips;
  final int totalCount;
  final bool isLoadingMore;
  final String? message;

  bool get hasMore => trips.length < totalCount;

  @override
  List<Object?> get props => [
    status,
    trips,
    totalCount,
    isLoadingMore,
    message,
  ];
}
