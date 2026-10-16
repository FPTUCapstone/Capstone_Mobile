import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';

enum TripHistoryStatus {
  initial,
  loading,
  success,
  failure,
  pendingIntegration,
}

final class TripHistoryState extends Equatable {
  const TripHistoryState({
    this.status = TripHistoryStatus.initial,
    this.selectedTab = TripStatus.upcoming,
    this.selectedTripType,
    this.startDate,
    this.endDate,
    this.page = 1,
    this.pageSize = 20,
    this.totalPages = 1,
    this.totalCount = 0,
    this.items = const <TripHistoryItem>[],
    this.errorMessage,
    this.validationError,
    this.isDemoMode = false,
    this.demoTravelerId,
  });

  final TripHistoryStatus status;
  final TripStatus selectedTab;
  final TripType? selectedTripType; // null indicates All
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;
  final int totalPages;
  final int totalCount;
  final List<TripHistoryItem> items;
  final String? errorMessage;
  final String? validationError;
  final bool isDemoMode;
  final int? demoTravelerId;

  bool get isLoading => status == TripHistoryStatus.loading;
  bool get isSuccess => status == TripHistoryStatus.success;
  bool get isFailure => status == TripHistoryStatus.failure;
  bool get isPendingIntegration =>
      status == TripHistoryStatus.pendingIntegration;
  bool get isEmpty => isSuccess && items.isEmpty;
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  TripHistoryState copyWith({
    TripHistoryStatus? status,
    TripStatus? selectedTab,
    TripType? Function()? selectedTripType,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    int? page,
    int? pageSize,
    int? totalPages,
    int? totalCount,
    List<TripHistoryItem>? items,
    String? Function()? errorMessage,
    String? Function()? validationError,
    bool? isDemoMode,
    int? Function()? demoTravelerId,
  }) {
    return TripHistoryState(
      status: status ?? this.status,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedTripType: selectedTripType != null
          ? selectedTripType()
          : this.selectedTripType,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      items: items ?? this.items,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      validationError: validationError != null
          ? validationError()
          : this.validationError,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      demoTravelerId: demoTravelerId != null
          ? demoTravelerId()
          : this.demoTravelerId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedTab,
    selectedTripType,
    startDate,
    endDate,
    page,
    pageSize,
    totalPages,
    totalCount,
    items,
    errorMessage,
    validationError,
    isDemoMode,
    demoTravelerId,
  ];
}
