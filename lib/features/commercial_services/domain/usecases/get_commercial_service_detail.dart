import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/repositories/commercial_services_repository.dart';

final class GetCommercialServiceDetail {
  const GetCommercialServiceDetail(this._repository);

  final CommercialServicesRepository _repository;

  Future<CommercialServiceDetailResult> call({
    required String rawPoiId,
    String? intendedDateIso,
    bool isDemoMode = false,
    DemoCommercialServiceScenario? demoScenario,
  }) {
    return _repository.getServiceDetail(
      rawPoiId: rawPoiId,
      intendedDateIso: intendedDateIso,
      isDemoMode: isDemoMode,
      demoScenario: demoScenario,
    );
  }
}
