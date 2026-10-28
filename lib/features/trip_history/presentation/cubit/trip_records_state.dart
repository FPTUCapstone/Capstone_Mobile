import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';

/// There is deliberately no "pending integration" status: the screen reads the
/// real TM-78 API, and a failure is an ordinary failure with Retry.
enum TripRecordsStatus { initial, loading, success, failure }

final class TripRecordsState extends Equatable {
  const TripRecordsState({
    this.status = TripRecordsStatus.initial,
    this.selectedTab = TripStatus.upcoming,
    this.tripType = TripRecordTypeFilter.all,
    this.startDate,
    this.endDate,
    this.page = 1,
    this.pageSize = TripRecordsQuery.defaultPageSize,
    this.totalPages = 1,
    this.totalCount = 0,
    this.items = const <TripRecord>[],
    this.summary,
    this.errorMessage,
    this.validationError,
  });

  final TripRecordsStatus status;
  final TripStatus selectedTab;
  final TripRecordTypeFilter tripType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;
  final int totalPages;
  final int totalCount;
  final List<TripRecord> items;

  /// Only on the Completed tab.
  final TripRecordSummary? summary;
  final String? errorMessage;
  final String? validationError;

  bool get isLoading => status == TripRecordsStatus.loading;
  bool get isSuccess => status == TripRecordsStatus.success;
  bool get isFailure => status == TripRecordsStatus.failure;
  bool get isEmpty => isSuccess && items.isEmpty;
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
  bool get hasActiveFilters =>
      tripType != TripRecordTypeFilter.all ||
      startDate != null ||
      endDate != null;

  TripRecordsState copyWith({
    TripRecordsStatus? status,
    TripStatus? selectedTab,
    TripRecordTypeFilter? tripType,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    int? page,
    int? totalPages,
    int? totalCount,
    List<TripRecord>? items,
    TripRecordSummary? Function()? summary,
    String? Function()? errorMessage,
    String? Function()? validationError,
  }) {
    return TripRecordsState(
      status: status ?? this.status,
      selectedTab: selectedTab ?? this.selectedTab,
      tripType: tripType ?? this.tripType,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      page: page ?? this.page,
      pageSize: pageSize,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      items: items ?? this.items,
      summary: summary != null ? summary() : this.summary,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      validationError: validationError != null
          ? validationError()
          : this.validationError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedTab,
    tripType,
    startDate,
    endDate,
    page,
    pageSize,
    totalPages,
    totalCount,
    items,
    summary,
    errorMessage,
    validationError,
  ];
}
