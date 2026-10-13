import 'package:trip_mate_mobile/features/commercial_services/data/datasources/commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/repositories/commercial_services_repository.dart';

final class CommercialServicesRepositoryImpl
    implements CommercialServicesRepository {
  const CommercialServicesRepositoryImpl({
    required CommercialServicesDataSource pendingDataSource,
    required CommercialServicesDataSource demoDataSource,
  }) : _pendingDataSource = pendingDataSource,
       _demoDataSource = demoDataSource;

  final CommercialServicesDataSource _pendingDataSource;
  final CommercialServicesDataSource _demoDataSource;

  @override
  Future<CommercialServicesSearchResult> searchServices({
    String? keyword,
    CommercialServiceCategory? category,
    String? dateIso,
    int? maxPriceVnd,
    int page = 1,
    int pageSize = 20,
    bool isDemoMode = false,
  }) {
    final dataSource = isDemoMode ? _demoDataSource : _pendingDataSource;
    return dataSource.searchServices(
      keyword: keyword,
      category: category,
      dateIso: dateIso,
      maxPriceVnd: maxPriceVnd,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<CommercialServiceDetailResult> getServiceDetail({
    required String rawPoiId,
    String? intendedDateIso,
    bool isDemoMode = false,
    DemoCommercialServiceScenario? demoScenario,
  }) {
    final dataSource = isDemoMode ? _demoDataSource : _pendingDataSource;
    return dataSource.getServiceDetail(
      rawPoiId: rawPoiId,
      intendedDateIso: intendedDateIso,
      demoScenario: demoScenario,
    );
  }
}
