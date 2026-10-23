import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_records_data.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';

/// DEMO ONLY. Answers the TM-78 queries from [DemoTripRecordsData] with the
/// same filtering, ordering, paging and summary rules as the backend.
final class DemoTripRecordsRepository implements TripRecordsRepository {
  const DemoTripRecordsRepository();

  static const _vietnamOffset = Duration(hours: 7);

  @override
  Future<TripRecordPage> getPage(TripRecordsQuery query) async {
    final from = query.startDate == null
        ? null
        : _vietnamDayStart(query.startDate!);
    final until = query.endDate == null
        ? null
        : _vietnamDayStart(query.endDate!).add(const Duration(days: 1));

    final matching = DemoTripRecordsData.details.where((detail) {
      final record = detail.record;
      if (record.tab != query.tab) return false;
      switch (query.tripType) {
        case TripRecordTypeFilter.all:
          break;
        case TripRecordTypeFilter.tourBooking:
          if (record is! BookingTripRecord) return false;
        case TripRecordTypeFilter.selfPlannedItinerary:
          if (record is! ItineraryTripRecord) return false;
      }
      final departure = record.departureAtUtc;
      if (from != null && departure.isBefore(from)) return false;
      if (until != null && !departure.isBefore(until)) return false;
      return true;
    }).toList()..sort((a, b) => _order(a.record, b.record));

    final start = (query.page - 1) * query.pageSize;
    final items = matching
        .skip(start)
        .take(query.pageSize)
        .map((detail) => detail.record)
        .toList(growable: false);
    return TripRecordPage(
      items: items,
      page: query.page,
      pageSize: query.pageSize,
      totalCount: matching.length,
      summary: query.tab == TripStatus.completed
          ? TripRecordSummary(
              totalCompletedTrips: matching.length,
              totalVisitedPois: matching.fold(0, (sum, detail) {
                final record = detail.record;
                return sum +
                    (record is ItineraryTripRecord
                        ? (record.visitedCount ?? 0)
                        : 0);
              }),
            )
          : null,
    );
  }

  @override
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id) async {
    for (final detail in DemoTripRecordsData.details) {
      if (detail.record.kind == kind && detail.record.id == id) return detail;
    }
    throw const NotFoundFailure();
  }

  /// Departure descending, then `commerceBooking` before `itinerary`, then id descending.
  static int _order(TripRecord left, TripRecord right) {
    final byDeparture = right.departureAtUtc.compareTo(left.departureAtUtc);
    if (byDeparture != 0) return byDeparture;
    if (left.kind != right.kind) return left.kind.index - right.kind.index;
    return right.id.compareTo(left.id);
  }

  /// The first instant, in UTC, of the Vietnam calendar day named by [day]'s year, month and day.
  static DateTime _vietnamDayStart(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).subtract(_vietnamOffset);
}
