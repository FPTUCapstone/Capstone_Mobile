import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class TripHistoryCubit extends Cubit<TripHistoryState> {
  TripHistoryCubit({
    required TripHistoryRepository repository,
    this.isDemoMode = false,
    this.demoTravelerId,
  }) : _repository = repository,
       super(
         TripHistoryState(
           isDemoMode: isDemoMode,
           demoTravelerId: demoTravelerId,
         ),
       );

  final TripHistoryRepository _repository;
  final bool isDemoMode;
  final int? demoTravelerId;

  Future<void> loadInitial() async {
    emit(
      state.copyWith(
        status: TripHistoryStatus.loading,
        errorMessage: () => null,
        validationError: () => null,
      ),
    );

    await _fetchTrips();
  }

  Future<void> switchTab(TripStatus tab) async {
    if (state.selectedTab == tab &&
        !state.isFailure &&
        !state.isPendingIntegration) {
      return;
    }

    emit(
      state.copyWith(
        selectedTab: tab,
        page: 1,
        status: TripHistoryStatus.loading,
        errorMessage: () => null,
      ),
    );

    await _fetchTrips();
  }

  Future<void> setTripType(TripType? type) async {
    if (state.selectedTripType == type &&
        !state.isFailure &&
        !state.isPendingIntegration) {
      return;
    }

    emit(
      state.copyWith(
        selectedTripType: () => type,
        page: 1,
        status: TripHistoryStatus.loading,
        errorMessage: () => null,
      ),
    );

    await _fetchTrips();
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    // Validation: The submitted date range is logically invalid
    // In Abnormal case 5.a1: MSG29 domain copy is displayed and the previous list remains unchanged.
    if (start != null && end != null && end.isBefore(start)) {
      emit(
        state.copyWith(
          validationError: () =>
              TripHistoryStringsEn.validationDateRangeInvalid,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        startDate: () => start,
        endDate: () => end,
        validationError: () => null,
        page: 1,
        status: TripHistoryStatus.loading,
        errorMessage: () => null,
      ),
    );

    await _fetchTrips();
  }

  Future<void> clearDateRange() async {
    emit(
      state.copyWith(
        startDate: () => null,
        endDate: () => null,
        validationError: () => null,
        page: 1,
        status: TripHistoryStatus.loading,
        errorMessage: () => null,
      ),
    );

    await _fetchTrips();
  }

  Future<void> goToPage(int page) async {
    if (page < 1 || page > state.totalPages || page == state.page) return;

    emit(
      state.copyWith(
        page: page,
        status: TripHistoryStatus.loading,
        errorMessage: () => null,
      ),
    );

    await _fetchTrips();
  }

  Future<void> retry() async {
    // In production mode, do NOT retry an endpoint that does not exist.
    if (state.isPendingIntegration) return;

    emit(
      state.copyWith(
        status: TripHistoryStatus.loading,
        errorMessage: () => null,
      ),
    );

    await _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    try {
      final result = await _repository.getTrips(
        travelerId: state.demoTravelerId,
        status: state.selectedTab,
        type: state.selectedTripType,
        startDate: state.startDate,
        endDate: state.endDate,
        page: state.page,
        pageSize: state.pageSize,
      );

      emit(
        state.copyWith(
          status: TripHistoryStatus.success,
          items: result.items,
          totalCount: result.totalCount,
          totalPages: result.totalPages,
          page: result.page,
          errorMessage: () => null,
        ),
      );
    } on ServerFailure catch (e) {
      final isPending =
          e.message == TripHistoryStringsEn.productionIntegrationPending;
      emit(
        state.copyWith(
          status: isPending
              ? TripHistoryStatus.pendingIntegration
              : TripHistoryStatus.failure,
          errorMessage: () => e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: TripHistoryStatus.failure,
          errorMessage: () => TripHistoryStringsEn.errorMessageGeneric,
        ),
      );
    }
  }
}
