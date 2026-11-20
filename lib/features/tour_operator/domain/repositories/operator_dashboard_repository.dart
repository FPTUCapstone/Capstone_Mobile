import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_dashboard_metrics.dart';

abstract interface class OperatorDashboardRepository {
  Future<OperatorDashboardMetrics> load();
}
