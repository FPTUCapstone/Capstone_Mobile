import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/repositories/commercial_services_repository.dart';

final class SearchCommercialServices {
  const SearchCommercialServices(this._repository);

  final CommercialServicesRepository _repository;

  Future<CommercialServicesSearchResult> call({
    String? keyword,
    CommercialServiceCategory? category,
    String? dateIso,
    int? maxPriceVnd,
    int page = 1,
    int pageSize = 20,
    bool isDemoMode = false,
  }) {
    return _repository.searchServices(
      keyword: keyword,
      category: category,
      dateIso: dateIso,
      maxPriceVnd: maxPriceVnd,
      page: page,
      pageSize: pageSize,
      isDemoMode: isDemoMode,
    );
  }
}
