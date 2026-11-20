import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_state.dart';

export 'operator_settlement_history_state.dart';

final class OperatorSettlementHistoryCubit
    extends Cubit<OperatorSettlementHistoryState> {
  OperatorSettlementHistoryCubit(this._repository)
    : super(const OperatorSettlementHistoryState());
  final OperatorFinanceRepository _repository;
  static const pageSize = 10;
  bool _started = false;
  int _generation = 0;
  int? _inFlightPage;
  int _retryPage = 1;
  bool _retryReset = true;

  Future<void> ensureLoaded() async {
    if (isClosed || _started) return;
    _started = true;
    await _request(1, resetScroll: true);
  }

  Future<void> changePage(int page) async {
    final history = state.history;
    if (isClosed ||
        state.loading ||
        history == null ||
        page < 1 ||
        page == history.pageNumber ||
        (page - 1) * pageSize >= history.totalCount) {
      return;
    }
    await _request(page, resetScroll: false);
  }

  Future<void> refresh() async {
    if (isClosed) return;
    if (!_started) return ensureLoaded();
    await _request(1, resetScroll: true);
  }

  Future<void> retry() => _request(_retryPage, resetScroll: _retryReset);

  Future<void> _request(int page, {required bool resetScroll}) async {
    if (isClosed || _inFlightPage == page) return;
    final generation = ++_generation;
    _inFlightPage = page;
    _retryPage = page;
    _retryReset = resetScroll;
    emit(state.copyWith(loading: true, clearError: true, forbidden: false));
    try {
      final history = await _repository.loadSettlementHistory(
        page: page,
        pageSize: pageSize,
      );
      if (isClosed || generation != _generation) return;
      _inFlightPage = null;
      emit(
        state.copyWith(
          history: history,
          loading: false,
          clearError: true,
          forbidden: false,
          scrollResetToken: state.scrollResetToken + (resetScroll ? 1 : 0),
        ),
      );
    } on Object catch (error) {
      if (isClosed || generation != _generation) return;
      _inFlightPage = null;
      final denied =
          error is PermissionFailure || error is AuthenticationFailure;
      emit(
        state.copyWith(
          loading: false,
          forbidden: denied,
          clearHistory: denied,
          error: _safeMessage(error),
        ),
      );
    }
  }

  static String _safeMessage(Object error) {
    if (error is AuthenticationFailure) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (error is PermissionFailure) {
      return 'Bạn không có quyền xem lịch sử quyết toán.';
    }
    if (error is NetworkFailure) {
      return 'Không thể kết nối. Vui lòng kiểm tra mạng và thử lại.';
    }
    return 'Không thể tải lịch sử quyết toán. Vui lòng thử lại.';
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
