import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_state.dart';

export 'operator_revenue_state.dart';

final class OperatorRevenueCubit extends Cubit<OperatorRevenueState> {
  OperatorRevenueCubit(
    this._repository, {
    DateTime Function()? now,
    RevenueQuery? initialQuery,
    bool includeTourOptions = true,
  }) : _now = now ?? DateTime.now,
       _includeTourOptions = includeTourOptions,
       super(
         OperatorRevenueState(
           query: initialQuery ?? _monthQuery((now ?? DateTime.now)(), 0),
         ),
       );

  final OperatorFinanceRepository _repository;
  final DateTime Function() _now;
  final bool _includeTourOptions;
  bool _started = false;
  int _generation = 0;
  int _optionsGeneration = 0;
  RevenueQuery? _inFlightQuery;
  RevenueQuery? _retryQuery;
  bool _retryReset = false;

  static RevenueQuery _monthQuery(DateTime now, int offset) {
    final vietnam = now.toUtc().add(const Duration(hours: 7));
    return RevenueQuery(
      startDate: DateTime(vietnam.year, vietnam.month + offset),
      endDate: DateTime(vietnam.year, vietnam.month + offset + 1, 0),
    );
  }

  RevenueQuery currentMonthQuery() => _preset(0);
  RevenueQuery previousMonthQuery() => _preset(-1);

  RevenueQuery _preset(int offset) {
    final period = _monthQuery(_now(), offset);
    return state.query.copyWith(
      startDate: period.startDate,
      endDate: period.endDate,
      page: 1,
    );
  }

  Future<void> ensureLoaded() async {
    if (isClosed || _started) return;
    _started = true;
    await Future.wait([
      _request(state.query, resetScroll: true),
      if (_includeTourOptions) loadOptions(),
    ]);
  }

  Future<void> apply(RevenueQuery query) async {
    if (isClosed) return;
    if (!query.isValid) {
      emit(
        state.copyWith(
          error: 'Vui lòng kiểm tra khoảng ngày và bộ lọc báo cáo.',
        ),
      );
      return;
    }
    if (!_started) {
      _started = true;
      if (_includeTourOptions) unawaited(loadOptions());
    }
    await _request(query.copyWith(page: 1), resetScroll: true);
  }

  Future<void> changePage(int page) async {
    final report = state.report;
    if (isClosed ||
        state.loading ||
        report == null ||
        page == state.query.page ||
        page < 1 ||
        page > report.totalPages) {
      return;
    }
    await _request(state.query.copyWith(page: page), resetScroll: false);
  }

  Future<void> refresh() async {
    if (isClosed) return;
    if (!_started) return ensureLoaded();
    await _request(state.query.copyWith(page: 1), resetScroll: true);
  }

  Future<void> retry() async {
    if (isClosed) return;
    await _request(_retryQuery ?? state.query, resetScroll: _retryReset);
  }

  Future<void> _request(RevenueQuery query, {required bool resetScroll}) async {
    if (isClosed || _inFlightQuery == query) return;
    if (!query.isValid) {
      emit(
        state.copyWith(
          error: 'Vui lòng kiểm tra khoảng ngày và bộ lọc báo cáo.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    _inFlightQuery = query;
    _retryQuery = query;
    _retryReset = resetScroll;
    emit(state.copyWith(loading: true, clearError: true, forbidden: false));
    try {
      final report = await _repository.loadReport(query);
      if (isClosed || generation != _generation) return;
      // Every response is a new report snapshot: summary, chart, rows and page
      // metadata change together even if only the requested page changed.
      _inFlightQuery = null;
      _retryQuery = null;
      emit(
        state.copyWith(
          query: query.copyWith(page: report.page, pageSize: report.pageSize),
          report: report,
          loading: false,
          clearError: true,
          forbidden: false,
          scrollResetToken: state.scrollResetToken + (resetScroll ? 1 : 0),
        ),
      );
    } on Object catch (error) {
      if (isClosed || generation != _generation) return;
      _inFlightQuery = null;
      final denied =
          error is PermissionFailure || error is AuthenticationFailure;
      if (denied) {
        _denyAccess(error);
        return;
      }
      emit(state.copyWith(loading: false, error: _safeMessage(error)));
    }
  }

  Future<void> loadOptions() async {
    if (isClosed || state.optionsLoading) return;
    final generation = ++_optionsGeneration;
    emit(state.copyWith(optionsLoading: true, clearOptionsError: true));
    try {
      final options = await _repository.loadTourOptions();
      if (isClosed || generation != _optionsGeneration) return;
      emit(
        state.copyWith(
          options: List.unmodifiable(options),
          optionsLoading: false,
          clearOptionsError: true,
        ),
      );
    } on Object catch (error) {
      if (isClosed || generation != _optionsGeneration) return;
      if (error is PermissionFailure || error is AuthenticationFailure) {
        _denyAccess(error);
        return;
      }
      emit(
        state.copyWith(
          optionsLoading: false,
          optionsError: _safeMessage(error),
        ),
      );
    }
  }

  void _denyAccess(Object error) {
    // Access loss invalidates both independent reads. A previously authorised
    // request must not restore money or owned-tour names after either GET denies.
    _generation++;
    _optionsGeneration++;
    _inFlightQuery = null;
    _retryQuery = state.query;
    _retryReset = true;
    final message = _safeMessage(error);
    emit(
      state.copyWith(
        clearReport: true,
        options: const [],
        loading: false,
        optionsLoading: false,
        forbidden: true,
        error: message,
        optionsError: message,
      ),
    );
  }

  static String _safeMessage(Object error) {
    if (error is AuthenticationFailure) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (error is PermissionFailure) {
      return 'Bạn không có quyền xem báo cáo này.';
    }
    if (error is ValidationFailure) {
      return 'Vui lòng kiểm tra khoảng ngày và bộ lọc báo cáo.';
    }
    if (error is NetworkFailure) {
      return 'Không thể kết nối. Vui lòng kiểm tra mạng và thử lại.';
    }
    return 'Không thể tải dữ liệu báo cáo. Vui lòng thử lại.';
  }

  @override
  Future<void> close() {
    _generation++;
    _optionsGeneration++;
    return super.close();
  }
}
