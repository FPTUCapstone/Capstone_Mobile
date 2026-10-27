import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';

enum OperatorBookingsStatus { loading, success, failure }

/// UC-40 list state: the filters, the page the backend returned, and its summary.
final class OperatorBookingsState extends Equatable {
  const OperatorBookingsState({
    this.status = OperatorBookingsStatus.loading,
    this.items = const [],
    this.summary = OperatorBookingsSummary.empty,
    this.page = 1,
    this.pageSize = OperatorBookingsQuery.defaultPageSize,
    this.totalCount = 0,
    this.totalPages = 0,
    this.loadingMore = false,
    this.loadMoreError,
    this.selectedStatus,
    this.tourId,
    this.departureFrom,
    this.departureTo,
    this.keyword,
    this.tourOptions = const [],
    this.tourOptionsFailed = false,
    this.errorMessage,
    this.canRetry = true,
    this.validationError,
  });

  final OperatorBookingsStatus status;
  final List<OperatorBookingListItem> items;
  final OperatorBookingsSummary summary;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool loadingMore;
  final String? loadMoreError;

  /// Null shows every status.
  final OperatorBookingStatus? selectedStatus;
  final String? tourId;
  final DateTime? departureFrom;
  final DateTime? departureTo;
  final String? keyword;

  final List<OperatorBookingTourOption> tourOptions;

  /// When the owned-tour list could not be loaded, the tour filter is disabled; the list is unaffected.
  final bool tourOptionsFailed;

  final String? errorMessage;

  /// False for an access failure: asking again cannot change the answer.
  final bool canRetry;

  /// The inline message under the departure range (MSG31); the previous list stays as it is.
  final String? validationError;

  bool get hasMore => page < totalPages;

  bool get isLoading => status == OperatorBookingsStatus.loading;

  bool get isFailure => status == OperatorBookingsStatus.failure;

  OperatorBookingsQuery query({int? page}) => OperatorBookingsQuery(
    tourId: tourId,
    status: selectedStatus,
    departureFrom: departureFrom,
    departureTo: departureTo,
    keyword: keyword,
    page: page ?? 1,
    pageSize: pageSize,
  );

  /// Nullable fields use a closure so that `() => null` clears them and an omitted argument keeps them.
  OperatorBookingsState copyWith({
    OperatorBookingsStatus? status,
    List<OperatorBookingListItem>? items,
    OperatorBookingsSummary? summary,
    int? page,
    int? pageSize,
    int? totalCount,
    int? totalPages,
    bool? loadingMore,
    String? Function()? loadMoreError,
    OperatorBookingStatus? Function()? selectedStatus,
    String? Function()? tourId,
    DateTime? Function()? departureFrom,
    DateTime? Function()? departureTo,
    String? Function()? keyword,
    List<OperatorBookingTourOption>? tourOptions,
    bool? tourOptionsFailed,
    String? Function()? errorMessage,
    bool? canRetry,
    String? Function()? validationError,
  }) => OperatorBookingsState(
    status: status ?? this.status,
    items: items ?? this.items,
    summary: summary ?? this.summary,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    totalCount: totalCount ?? this.totalCount,
    totalPages: totalPages ?? this.totalPages,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
    selectedStatus: selectedStatus != null
        ? selectedStatus()
        : this.selectedStatus,
    tourId: tourId != null ? tourId() : this.tourId,
    departureFrom: departureFrom != null ? departureFrom() : this.departureFrom,
    departureTo: departureTo != null ? departureTo() : this.departureTo,
    keyword: keyword != null ? keyword() : this.keyword,
    tourOptions: tourOptions ?? this.tourOptions,
    tourOptionsFailed: tourOptionsFailed ?? this.tourOptionsFailed,
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    canRetry: canRetry ?? this.canRetry,
    validationError: validationError != null
        ? validationError()
        : this.validationError,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    summary,
    page,
    pageSize,
    totalCount,
    totalPages,
    loadingMore,
    loadMoreError,
    selectedStatus,
    tourId,
    departureFrom,
    departureTo,
    keyword,
    tourOptions,
    tourOptionsFailed,
    errorMessage,
    canRetry,
    validationError,
  ];
}
