import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/usecases/operator_bookings_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_failure_copy.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

/// UC-40 list: status, search, tour and departure range filters, and paging over the backend list.
///
/// The summary and the paging come from the backend and are never recomputed here. Only the canonical
/// copy of [OperatorBookingsStringsEn] reaches the screen, never a server body or an exception text.
final class OperatorBookingsCubit extends Cubit<OperatorBookingsState> {
  OperatorBookingsCubit({
    required ListOperatorBookingsUseCase listBookings,
    required LoadOperatorBookingTourOptionsUseCase loadTourOptions,
  }) : _listBookings = listBookings,
       _loadTourOptions = loadTourOptions,
       super(const OperatorBookingsState());

  final ListOperatorBookingsUseCase _listBookings;
  final LoadOperatorBookingTourOptionsUseCase _loadTourOptions;

  /// Identifies the latest list request; an answer for an older one is dropped.
  int _requestId = 0;

  Future<void> loadInitial() =>
      Future.wait([_loadOptions(), _load(state)]).then((_) {});

  Future<void> selectStatus(OperatorBookingStatus? status) {
    if (state.selectedStatus == status && !state.isFailure) {
      return Future.value();
    }
    return _load(state.copyWith(selectedStatus: () => status));
  }

  Future<void> search(String keyword) {
    final trimmed = keyword.trim();
    final next = trimmed.isEmpty ? null : trimmed;
    if (state.keyword == next && !state.isFailure) return Future.value();
    return _load(state.copyWith(keyword: () => next));
  }

  /// [departureFrom] and [departureTo] are the days picked by the user; only their year, month and day
  /// count (they are sent as Vietnam days). An inverted range is rejected here with the MSG31 text, before
  /// any request, and the previous list stays as it is.
  Future<void> applyFilters({
    String? tourId,
    DateTime? departureFrom,
    DateTime? departureTo,
  }) {
    final from = departureFrom == null
        ? null
        : TripFormatters.toCivilCalendarDay(departureFrom);
    final to = departureTo == null
        ? null
        : TripFormatters.toCivilCalendarDay(departureTo);
    if (from != null && to != null && to.isBefore(from)) {
      emit(
        state.copyWith(
          validationError: () => OperatorBookingsStringsEn.dateRangeInvalid,
        ),
      );
      return Future.value();
    }
    return _load(
      state.copyWith(
        tourId: () => tourId,
        departureFrom: () => from,
        departureTo: () => to,
        validationError: () => null,
      ),
    );
  }

  /// The filter sheet's "Reset": back to every tour and no departure range, in one request.
  Future<void> clearFilters() => _load(
    state.copyWith(
      tourId: () => null,
      departureFrom: () => null,
      departureTo: () => null,
      validationError: () => null,
    ),
  );

  Future<void> refresh() => _load(state);

  Future<void> retry() async {
    if (state.tourOptionsFailed) await _loadOptions();
    await _load(state);
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.status != OperatorBookingsStatus.success) {
      return;
    }
    final request = _requestId;
    final target = state;
    emit(state.copyWith(loadingMore: true, loadMoreError: () => null));
    try {
      final result = await _listBookings(target.query(page: target.page + 1));
      // A newer request has taken over (or the screen is gone): drop this page.
      if (isClosed || request != _requestId) return;
      final known = {for (final item in state.items) item.bookingId};
      emit(
        state.copyWith(
          items: [
            ...state.items,
            ...result.items.where((item) => !known.contains(item.bookingId)),
          ],
          summary: result.summary,
          page: result.page,
          totalCount: result.totalCount,
          totalPages: result.totalPages,
          loadingMore: false,
        ),
      );
    } on Object catch (error) {
      if (isClosed || request != _requestId) return;
      emit(
        state.copyWith(
          loadingMore: false,
          loadMoreError: () => OperatorBookingFailureCopy.of(error).message,
        ),
      );
    }
  }

  Future<void> _load(OperatorBookingsState target) async {
    final request = ++_requestId;
    emit(
      target.copyWith(
        status: OperatorBookingsStatus.loading,
        loadingMore: false,
        loadMoreError: () => null,
        errorMessage: () => null,
      ),
    );
    try {
      final result = await _listBookings(target.query());
      if (isClosed || request != _requestId) return;
      emit(
        state.copyWith(
          status: OperatorBookingsStatus.success,
          items: result.items,
          summary: result.summary,
          page: result.page,
          pageSize: result.pageSize,
          totalCount: result.totalCount,
          totalPages: result.totalPages,
          errorMessage: () => null,
          canRetry: true,
        ),
      );
    } on Object catch (error) {
      if (isClosed || request != _requestId) return;
      final failure = OperatorBookingFailureCopy.of(error);
      emit(
        state.copyWith(
          status: OperatorBookingsStatus.failure,
          items: const [],
          errorMessage: () => failure.message,
          canRetry: failure.canRetry,
        ),
      );
    }
  }

  Future<void> _loadOptions() async {
    try {
      final options = await _loadTourOptions();
      if (isClosed) return;
      emit(state.copyWith(tourOptions: options, tourOptionsFailed: false));
    } on Object {
      // Only the tour filter is lost; the list never depends on it.
      if (isClosed) return;
      emit(state.copyWith(tourOptions: const [], tourOptionsFailed: true));
    }
  }
}
