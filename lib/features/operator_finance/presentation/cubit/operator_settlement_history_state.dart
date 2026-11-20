import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';

final class OperatorSettlementHistoryState {
  const OperatorSettlementHistoryState({
    this.history,
    this.loading = false,
    this.error,
    this.forbidden = false,
    this.scrollResetToken = 0,
  });

  final SettlementHistory? history;
  final bool loading;
  final String? error;
  final bool forbidden;
  final int scrollResetToken;

  OperatorSettlementHistoryState copyWith({
    SettlementHistory? history,
    bool clearHistory = false,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? forbidden,
    int? scrollResetToken,
  }) => OperatorSettlementHistoryState(
    history: clearHistory ? null : history ?? this.history,
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
    forbidden: forbidden ?? this.forbidden,
    scrollResetToken: scrollResetToken ?? this.scrollResetToken,
  );
}
