import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';

abstract interface class CommercialServicesRepository {
  Future<CommercialServicesSearchResult> searchServices({
    String? keyword,
    CommercialServiceCategory? category,
    String? dateIso,
    int? maxPriceVnd,
    int page = 1,
    int pageSize = 20,
    bool isDemoMode = false,
  });

  Future<CommercialServiceDetailResult> getServiceDetail({
    required String rawPoiId,
    String? intendedDateIso,
    bool isDemoMode = false,
    DemoCommercialServiceScenario? demoScenario,
  });
}
