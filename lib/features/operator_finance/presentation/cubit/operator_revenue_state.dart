import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';

final class OperatorRevenueState {
  const OperatorRevenueState({
    required this.query,
    this.report,
    this.loading = false,
    this.error,
    this.forbidden = false,
    this.options = const [],
    this.optionsLoading = false,
    this.optionsError,
    this.scrollResetToken = 0,
  });

  /// The query belonging to [report], never an in-flight draft filter.
  final RevenueQuery query;
  final RevenueReport? report;
  final bool loading;
  final String? error;
  final bool forbidden;
  final List<RevenueTourOption> options;
  final bool optionsLoading;
  final String? optionsError;
  final int scrollResetToken;

  OperatorRevenueState copyWith({
    RevenueQuery? query,
    RevenueReport? report,
    bool clearReport = false,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? forbidden,
    List<RevenueTourOption>? options,
    bool? optionsLoading,
    String? optionsError,
    bool clearOptionsError = false,
    int? scrollResetToken,
  }) => OperatorRevenueState(
    query: query ?? this.query,
    report: clearReport ? null : report ?? this.report,
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
    forbidden: forbidden ?? this.forbidden,
    options: options ?? this.options,
    optionsLoading: optionsLoading ?? this.optionsLoading,
    optionsError: clearOptionsError ? null : optionsError ?? this.optionsError,
    scrollResetToken: scrollResetToken ?? this.scrollResetToken,
  );
}
