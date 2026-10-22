import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';

/// The trip-type filter of the TM-78 list; `all` is sent by omitting the parameter.
enum TripRecordTypeFilter {
  all(null),
  tourBooking('TourBooking'),
  selfPlannedItinerary('SelfPlannedItinerary');

  const TripRecordTypeFilter(this.wireValue);

  final String? wireValue;
}

/// What the TM-78 list endpoint accepts.
///
/// [startDate] and [endDate] are calendar days (the year, month and day are
/// what is sent, as Vietnam days); the caller normalises them, for example with
/// `TripFormatters.toCivilCalendarDay`.
final class TripRecordsQuery extends Equatable {
  const TripRecordsQuery({
    required this.tab,
    this.tripType = TripRecordTypeFilter.all,
    this.startDate,
    this.endDate,
    this.page = 1,
    this.pageSize = defaultPageSize,
  });

  /// CR-01.
  static const int defaultPageSize = 20;

  /// The backend rejects `page * pageSize` above this, so it is also the deepest page the app asks for.
  static const int maxWindowKeys = 1000;

  final TripStatus tab;
  final TripRecordTypeFilter tripType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;

  @override
  List<Object?> get props => [
    tab,
    tripType,
    startDate,
    endDate,
    page,
    pageSize,
  ];
}

abstract interface class TripRecordsRepository {
  /// The signed-in Traveler's trips for one tab (UC-32).
  Future<TripRecordPage> getPage(TripRecordsQuery query);

  /// One record the Traveler owns, identified by (kind, id).
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id);
}
