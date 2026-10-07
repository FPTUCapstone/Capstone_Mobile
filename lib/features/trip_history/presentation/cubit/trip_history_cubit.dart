import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class TripHistoryCubit extends Cubit<TripHistoryState> {
  TripHistoryCubit({
    required TripHistoryRepository repository,
    int defaultTravelerId = 1,
  }) : _repository = repository,
       super(TripHistoryState(travelerId: defaultTravelerId));

  final TripHistoryRepository _repository;

  Future<void> loadInitial({int? travelerId}) async {
    final tId = travelerId ?? state.travelerId;
    emit(
      state.copyWith(
        travelerId: tId,
        status: TripHistoryStatus.loading,
        errorMessage: () => null,
        validationError: () => null,
      ),
    );

    await _fetchTrips();
  }

  Future<void> switchTab(TripStatus tab) async {
    if (state.selectedTab == tab && !state.isFailure) return;

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
    if (state.selectedTripType == type && !state.isFailure) return;

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
    // In Abnormal case 5.a1: MSG29 is displayed and the previous list remains unchanged.
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
        travelerId: state.travelerId,
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
    } catch (e) {
      emit(
        state.copyWith(
          status: TripHistoryStatus.failure,
          errorMessage: () => TripHistoryStringsEn.errorMessageGeneric,
        ),
      );
    }
  }
}
