import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

enum TourDetailStatus { initial, loading, pendingIntegration, error, success }

final class TourDetailState extends Equatable {
  const TourDetailState({
    required this.status,
    this.tourDetail,
    this.initialSummary,
    this.selectedScheduleId,
    this.scheduleError,
    this.errorMessage,
    this.isDemoMode = false,
  });

  const TourDetailState.initial({
    TourSummary? initialSummary,
    bool isDemoMode = false,
  }) : this(
         status: TourDetailStatus.initial,
         initialSummary: initialSummary,
         isDemoMode: isDemoMode,
       );

  const TourDetailState.loading({
    TourSummary? initialSummary,
    bool isDemoMode = false,
  }) : this(
         status: TourDetailStatus.loading,
         initialSummary: initialSummary,
         isDemoMode: isDemoMode,
       );

  const TourDetailState.pendingIntegration({
    TourSummary? initialSummary,
    bool isDemoMode = false,
  }) : this(
         status: TourDetailStatus.pendingIntegration,
         initialSummary: initialSummary,
         isDemoMode: isDemoMode,
       );

  const TourDetailState.error(
    String message, {
    TourSummary? initialSummary,
    bool isDemoMode = false,
  }) : this(
         status: TourDetailStatus.error,
         errorMessage: message,
         initialSummary: initialSummary,
         isDemoMode: isDemoMode,
       );

  const TourDetailState.success({
    required TourDetail tourDetail,
    TourSummary? initialSummary,
    String? selectedScheduleId,
    String? scheduleError,
    bool isDemoMode = false,
  }) : this(
         status: TourDetailStatus.success,
         tourDetail: tourDetail,
         initialSummary: initialSummary,
         selectedScheduleId: selectedScheduleId,
         scheduleError: scheduleError,
         isDemoMode: isDemoMode,
       );

  final TourDetailStatus status;
  final TourDetail? tourDetail;
  final TourSummary? initialSummary;
  final String? selectedScheduleId;
  final String? scheduleError;
  final String? errorMessage;
  final bool isDemoMode;

  bool get isLoading => status == TourDetailStatus.loading;

  TourScheduleItem? get selectedSchedule {
    if (tourDetail == null || selectedScheduleId == null) return null;
    return tourDetail!.schedules.cast<TourScheduleItem?>().firstWhere(
      (s) => s?.scheduleId == selectedScheduleId,
      orElse: () => null,
    );
  }

  /// MSG65: The selected departure date has no remaining slots.
  static const String msg65 =
      'The selected departure date has no remaining slots. Please choose another departure date.';

  /// MSG128: No published reviews yet.
  static const String msg128 =
      'There are no published reviews for this tour yet.';

  /// MSG127: System/network failure.
  static const String msg127 =
      'TripMate is temporarily unable to process your request. Please check your connection and try again.';

  TourDetailState copyWith({
    TourDetailStatus? status,
    TourDetail? tourDetail,
    TourSummary? initialSummary,
    String? selectedScheduleId,
    String? scheduleError,
    bool clearScheduleError = false,
    String? errorMessage,
    bool? isDemoMode,
  }) {
    return TourDetailState(
      status: status ?? this.status,
      tourDetail: tourDetail ?? this.tourDetail,
      initialSummary: initialSummary ?? this.initialSummary,
      selectedScheduleId: selectedScheduleId ?? this.selectedScheduleId,
      scheduleError: clearScheduleError
          ? null
          : (scheduleError ?? this.scheduleError),
      errorMessage: errorMessage ?? this.errorMessage,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    tourDetail,
    initialSummary,
    selectedScheduleId,
    scheduleError,
    errorMessage,
    isDemoMode,
  ];
}
