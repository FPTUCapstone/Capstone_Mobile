import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/datasources/commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';

final class PendingCommercialServicesDataSource
    implements CommercialServicesDataSource {
  const PendingCommercialServicesDataSource({PoiRepository? poiRepository})
    : _poiRepository = poiRepository;

  final PoiRepository? _poiRepository;

  @override
  Future<CommercialServicesSearchResult> searchServices({
    String? keyword,
    CommercialServiceCategory? category,
    String? dateIso,
    int? maxPriceVnd,
    int page = 1,
    int pageSize = 20,
  }) async {
    // Fail-closed production behavior:
    // Standalone commercial catalog classification and category filtering remain
    // pending server integration. Returns pending integration immediately without
    // issuing unused POI requests.
    return const CommercialServicesSearchPending();
  }

  @override
  Future<CommercialServiceDetailResult> getServiceDetail({
    required String rawPoiId,
    String? intendedDateIso,
    DemoCommercialServiceScenario? demoScenario,
  }) async {
    final poiId = int.tryParse(rawPoiId);
    if (poiId == null || poiId <= 0) {
      return CommercialServiceDetailInactiveOrNotFound(
        message: CommercialServiceMessages.msg34,
      );
    }

    final repo = _poiRepository;
    if (repo == null) {
      return CommercialServiceDetailFailure(
        message: CommercialServiceMessages.msg127,
      );
    }

    try {
      final detail = await repo.getPoiDetail(poiId);
      if (detail.status.trim().toLowerCase() != 'active') {
        // BR-34: Detailed information is displayed only while status is Active.
        return CommercialServiceDetailInactiveOrNotFound(
          message: CommercialServiceMessages.msg34,
        );
      }

      final composite = CommercialServiceDetailComposite.fromProductionPoi(
        detail,
      );
      return CommercialServiceDetailLoaded(composite: composite);
    } on NotFoundFailure {
      return CommercialServiceDetailInactiveOrNotFound(
        message: CommercialServiceMessages.msg34,
      );
    } on Failure {
      return CommercialServiceDetailFailure(
        message: CommercialServiceMessages.msg127,
      );
    } on Object {
      return CommercialServiceDetailFailure(
        message: CommercialServiceMessages.msg127,
      );
    }
  }
}
