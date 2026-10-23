import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/trip_records_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

/// UC-32 list state: tab, trip type, date range and paging over the TM-78 API.
final class TripRecordsCubit extends Cubit<TripRecordsState> {
  TripRecordsCubit({required TripRecordsUseCase useCase})
    : _useCase = useCase,
      super(const TripRecordsState());

  /// The backend rejects `page * pageSize` above 1000, so no deeper page is offered.
  static const int maxPages =
      TripRecordsQuery.maxWindowKeys ~/ TripRecordsQuery.defaultPageSize;

  static const String _invalidDateRange = 'trip_history.invalid_date_range';

  final TripRecordsUseCase _useCase;
  int _requestId = 0;

  Future<void> loadInitial() => _load(state);

  Future<void> switchTab(TripStatus tab) {
    if (state.selectedTab == tab && !state.isFailure) return Future.value();
    return _load(state.copyWith(selectedTab: tab, page: 1));
  }

  Future<void> setTripType(TripRecordTypeFilter type) {
    if (state.tripType == type && !state.isFailure) return Future.value();
    return _load(state.copyWith(tripType: type, page: 1));
  }

  /// [start] and [end] are calendar days picked by the user; only their year,
  /// month and day count (they are sent as Vietnam days).
  Future<void> setDateRange(DateTime? start, DateTime? end) {
    final from = start == null
        ? null
        : TripFormatters.toCivilCalendarDay(start);
    final to = end == null ? null : TripFormatters.toCivilCalendarDay(end);
    if (from != null && to != null && to.isBefore(from)) {
      // MSG29: the previous list stays as it is.
      emit(
        state.copyWith(
          validationError: () =>
              TripHistoryStringsEn.validationDateRangeInvalid,
        ),
      );
      return Future.value();
    }
    return _load(
      state.copyWith(
        startDate: () => from,
        endDate: () => to,
        validationError: () => null,
        page: 1,
      ),
    );
  }

  Future<void> clearDateRange() => _load(
    state.copyWith(
      startDate: () => null,
      endDate: () => null,
      validationError: () => null,
      page: 1,
    ),
  );

  /// "Reset": back to every trip type and no date range, in one request.
  Future<void> clearFilters() => _load(
    state.copyWith(
      tripType: TripRecordTypeFilter.all,
      startDate: () => null,
      endDate: () => null,
      validationError: () => null,
      page: 1,
    ),
  );

  Future<void> goToPage(int page) {
    if (page < 1 || page > state.totalPages || page == state.page) {
      return Future.value();
    }
    return _load(state.copyWith(page: page));
  }

  Future<void> retry() => _load(state);

  Future<void> _load(TripRecordsState target) async {
    final request = ++_requestId;
    emit(
      target.copyWith(
        status: TripRecordsStatus.loading,
        errorMessage: () => null,
      ),
    );

    try {
      final result = await _useCase.page(
        TripRecordsQuery(
          tab: target.selectedTab,
          tripType: target.tripType,
          startDate: target.startDate,
          endDate: target.endDate,
          page: target.page,
          pageSize: target.pageSize,
        ),
      );
      // A newer request has taken over (or the screen is gone): drop this answer.
      if (isClosed || request != _requestId) return;
      emit(
        state.copyWith(
          status: TripRecordsStatus.success,
          items: result.items,
          summary: () => result.summary,
          totalCount: result.totalCount,
          totalPages: result.totalPages.clamp(1, maxPages),
          page: result.page,
          errorMessage: () => null,
        ),
      );
    } on Object catch (error) {
      if (isClosed || request != _requestId) return;
      emit(
        state.copyWith(
          status: TripRecordsStatus.failure,
          errorMessage: () => _message(error),
        ),
      );
    }
  }

  /// Only canonical copy ever reaches the screen, never a server body or exception text.
  String _message(Object error) => switch (error) {
    AuthenticationFailure() ||
    PermissionFailure() => TripHistoryStringsEn.permissionDenied,
    ValidationFailure(:final message) when message == _invalidDateRange =>
      TripHistoryStringsEn.validationDateRangeInvalid,
    _ => TripHistoryStringsEn.errorMessageGeneric,
  };
}
