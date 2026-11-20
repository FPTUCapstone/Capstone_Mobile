import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_dashboard_metrics.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_dashboard_repository.dart';

final class OperatorDashboardState {
  const OperatorDashboardState({
    this.loading = false,
    this.failed = false,
    this.metrics,
  });
  final bool loading;
  final bool failed;
  final OperatorDashboardMetrics? metrics;
}

final class OperatorDashboardCubit extends Cubit<OperatorDashboardState> {
  OperatorDashboardCubit(this._repository)
    : super(const OperatorDashboardState());
  final OperatorDashboardRepository _repository;

  Future<void> load() async {
    if (isClosed || state.loading) return;
    emit(const OperatorDashboardState(loading: true));
    try {
      final metrics = await _repository.load();
      if (!isClosed) emit(OperatorDashboardState(metrics: metrics));
    } on Object {
      if (!isClosed) emit(const OperatorDashboardState(failed: true));
    }
  }
}
