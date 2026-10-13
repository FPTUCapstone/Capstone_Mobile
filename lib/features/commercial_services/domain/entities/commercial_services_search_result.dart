import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_list_item.dart';

sealed class CommercialServicesSearchResult {
  const CommercialServicesSearchResult();
}

final class CommercialServicesSearchPending
    extends CommercialServicesSearchResult {
  const CommercialServicesSearchPending({this.message});

  final String? message;
}

final class CommercialServicesSearchSuccess
    extends CommercialServicesSearchResult {
  const CommercialServicesSearchSuccess({
    required this.items,
    this.totalCount = 0,
    this.page = 1,
    this.totalPages = 1,
  });

  final List<CommercialServiceListItem> items;
  final int totalCount;
  final int page;
  final int totalPages;
}

final class CommercialServicesSearchFailure
    extends CommercialServicesSearchResult {
  const CommercialServicesSearchFailure({this.message});

  final String? message;
}
