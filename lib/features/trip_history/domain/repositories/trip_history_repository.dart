import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';

final class TripHistoryPageResult extends Equatable {
  const TripHistoryPageResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<TripHistoryItem> items;
  final int totalCount;
  final int page;
  final int pageSize;

  int get totalPages => (totalCount / pageSize).ceil().clamp(1, 9999);
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  @override
  List<Object?> get props => [items, totalCount, page, pageSize];
}

abstract interface class TripHistoryRepository {
  /// Returns bookings and itineraries.
  /// In demo mode, returns records for [travelerId] (defaulting to demo traveler).
  /// In production mode, yields truthful PENDING_BE_INTEGRATION result.
  /// CR-01 & BR-52: Paginated results (default 20 records per page).
  Future<TripHistoryPageResult> getTrips({
    int? travelerId,
    TripStatus? status,
    TripType? type,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  });

  Future<TripHistoryItem?> getTripById({
    int? travelerId,
    required String tripId,
  });
}
