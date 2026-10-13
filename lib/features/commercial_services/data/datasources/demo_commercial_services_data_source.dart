import 'package:trip_mate_mobile/features/commercial_services/data/datasources/commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/datasources/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';

final class DemoCommercialServicesDataSource
    implements CommercialServicesDataSource {
  const DemoCommercialServicesDataSource({
    DemoCommercialServiceStore? demoStore,
  }) : _demoStore = demoStore;

  final DemoCommercialServiceStore? _demoStore;

  DemoCommercialServiceStore get _store =>
      _demoStore ?? DemoCommercialServiceStore.instance;

  @override
  Future<CommercialServicesSearchResult> searchServices({
    String? keyword,
    CommercialServiceCategory? category,
    String? dateIso,
    int? maxPriceVnd,
    int page = 1,
    int pageSize = 20,
  }) async {
    final items = _store.getDemoCatalogItems(
      keyword: keyword,
      category: category,
      dateIso: dateIso,
      maxPriceVnd: maxPriceVnd,
    );

    return CommercialServicesSearchSuccess(
      items: items,
      totalCount: items.length,
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<CommercialServiceDetailResult> getServiceDetail({
    required String rawPoiId,
    String? intendedDateIso,
    DemoCommercialServiceScenario? demoScenario,
  }) async {
    final effectiveDate =
        (intendedDateIso != null && intendedDateIso.trim().isNotEmpty)
        ? intendedDateIso.trim()
        : DemoCommercialServiceStore.defaultIntendedDateIso;

    final scenario =
        demoScenario ??
        DemoCommercialServiceScenario.fromPoiId(int.tryParse(rawPoiId) ?? 901);

    if (scenario == DemoCommercialServiceScenario.systemFailure) {
      return CommercialServiceDetailFailure(
        message: CommercialServiceMessages.msg127,
      );
    }

    final composite = _store.resolveComposite(
      scenario: scenario,
      intendedDateIso: effectiveDate,
    );

    if (!composite.isActivePoi) {
      return CommercialServiceDetailInactiveOrNotFound(
        message: CommercialServiceMessages.msg34,
      );
    }

    final notice = composite.isOpenForBooking == false
        ? CommercialServiceMessages.msg75
        : null;

    return CommercialServiceDetailLoaded(
      composite: composite,
      noticeMessage: notice,
    );
  }
}
