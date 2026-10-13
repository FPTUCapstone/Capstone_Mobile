import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/datasources/demo_commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/datasources/pending_commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/repositories/commercial_services_repository_impl.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';

class _MockPoiRepository implements PoiRepository {
  _MockPoiRepository({this.onGetPoiDetail, this.onGetPois});

  final Future<PoiDetail> Function(int id)? onGetPoiDetail;
  final Future<PagedPoiResult> Function(PoiQuery query)? onGetPois;

  @override
  Future<PoiDetail> getPoiDetail(int id) async {
    if (onGetPoiDetail != null) {
      return onGetPoiDetail!(id);
    }
    throw const NotFoundFailure('POI not found');
  }

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) async {
    if (onGetPois != null) {
      return onGetPois!(query);
    }
    throw UnimplementedError();
  }
}

PoiDetail _buildTestPoi({
  required int id,
  required String name,
  required String categoryName,
  String status = 'Active',
}) {
  return PoiDetail(
    id: id,
    name: name,
    description: 'Description of $name',
    status: status,
    categoryId: 1,
    categoryName: categoryName,
    latitude: 16.05,
    longitude: 108.20,
    address: 'Da Nang, Vietnam',
    indoorOutdoor: 'Indoor',
    averageVisitDurationMinutes: 60,
    hasShelter: true,
    scenicScore: 4.5,
    photoRating: 4.5,
    averageRating: 4.5,
    reviewCount: 50,
    isOpenNow: true,
    openingHours: const [],
    photos: const [],
    tags: const [],
    createdAtUtc: DateTime.utc(2026, 1, 1),
    updatedAtUtc: DateTime.utc(2026, 1, 2),
  );
}

void main() {
  group('CommercialServicesRepositoryImpl & DataSources', () {
    test(
      'Production searchServices fails closed with pendingIntegration and makes zero POI calls',
      () async {
        var poiCallsMade = 0;
        final mockPoiRepo = _MockPoiRepository(
          onGetPois: (query) async {
            poiCallsMade++;
            return const PagedPoiResult(
              page: 1,
              pageSize: 20,
              totalCount: 0,
              totalPages: 0,
              items: [],
            );
          },
        );

        final repository = CommercialServicesRepositoryImpl(
          pendingDataSource: PendingCommercialServicesDataSource(
            poiRepository: mockPoiRepo,
          ),
          demoDataSource: const DemoCommercialServicesDataSource(),
        );

        final result = await repository.searchServices(
          keyword: 'hotel',
          category: CommercialServiceCategory.hotel,
          isDemoMode: false,
        );

        expect(result, isA<CommercialServicesSearchPending>());
        expect(poiCallsMade, equals(0));
      },
    );

    test(
      'Demo searchServices queries demo store with multi-criteria filters',
      () async {
        final repository = CommercialServicesRepositoryImpl(
          pendingDataSource: const PendingCommercialServicesDataSource(),
          demoDataSource: const DemoCommercialServicesDataSource(),
        );

        final result = await repository.searchServices(
          category: CommercialServiceCategory.hotel,
          isDemoMode: true,
        );

        expect(result, isA<CommercialServicesSearchSuccess>());
        final success = result as CommercialServicesSearchSuccess;
        expect(success.items, isNotEmpty);
        expect(
          success.items.every(
            (i) => i.category == CommercialServiceCategory.hotel,
          ),
          isTrue,
        );
      },
    );

    test(
      'Production getServiceDetail returns inactiveOrNotFound for invalid POI ID or inactive POI (BR-34)',
      () async {
        final mockPoiRepo = _MockPoiRepository(
          onGetPoiDetail: (id) async => _buildTestPoi(
            id: id,
            name: 'Closed Hotel',
            categoryName: 'Hotel',
            status: 'Inactive',
          ),
        );

        final repository = CommercialServicesRepositoryImpl(
          pendingDataSource: PendingCommercialServicesDataSource(
            poiRepository: mockPoiRepo,
          ),
          demoDataSource: const DemoCommercialServicesDataSource(),
        );

        // Invalid ID
        final invalidIdResult = await repository.getServiceDetail(
          rawPoiId: 'abc',
          isDemoMode: false,
        );
        expect(
          invalidIdResult,
          isA<CommercialServiceDetailInactiveOrNotFound>(),
        );
        expect(
          (invalidIdResult as CommercialServiceDetailInactiveOrNotFound)
              .message,
          equals(CommercialServiceMessages.msg34),
        );

        // Inactive POI
        final inactiveResult = await repository.getServiceDetail(
          rawPoiId: '10',
          isDemoMode: false,
        );
        expect(
          inactiveResult,
          isA<CommercialServiceDetailInactiveOrNotFound>(),
        );
        expect(
          (inactiveResult as CommercialServiceDetailInactiveOrNotFound).message,
          equals(CommercialServiceMessages.msg34),
        );
      },
    );

    test(
      'Production getServiceDetail returns loaded composite for active commercial POI without fabricating options',
      () async {
        final mockPoiRepo = _MockPoiRepository(
          onGetPoiDetail: (id) async => _buildTestPoi(
            id: id,
            name: 'Live Beach Resort',
            categoryName: 'Hotel',
            status: 'Active',
          ),
        );

        final repository = CommercialServicesRepositoryImpl(
          pendingDataSource: PendingCommercialServicesDataSource(
            poiRepository: mockPoiRepo,
          ),
          demoDataSource: const DemoCommercialServicesDataSource(),
        );

        final result = await repository.getServiceDetail(
          rawPoiId: '10',
          isDemoMode: false,
        );

        expect(result, isA<CommercialServiceDetailLoaded>());
        final loaded = result as CommercialServiceDetailLoaded;
        expect(loaded.composite.poi.name, equals('Live Beach Resort'));
        expect(
          loaded.composite.commercialCategory,
          equals(CommercialServiceCategory.hotel),
        );
        expect(loaded.composite.isCommercialDataBackedByServer, isFalse);
        expect(loaded.composite.options, isEmpty);
        expect(loaded.composite.canBookService, isFalse);
      },
    );

    test(
      'Demo getServiceDetail resolves scenarios deterministically',
      () async {
        final repository = CommercialServicesRepositoryImpl(
          pendingDataSource: const PendingCommercialServicesDataSource(),
          demoDataSource: const DemoCommercialServicesDataSource(),
        );

        // Available Hotel (901)
        final hotelResult = await repository.getServiceDetail(
          rawPoiId: '901',
          isDemoMode: true,
        );
        expect(hotelResult, isA<CommercialServiceDetailLoaded>());
        final hotelLoaded = hotelResult as CommercialServiceDetailLoaded;
        expect(hotelLoaded.composite.canBookService, isTrue);

        // Closed for booking (907)
        final closedResult = await repository.getServiceDetail(
          rawPoiId: '907',
          isDemoMode: true,
          demoScenario: DemoCommercialServiceScenario.closedForBooking,
        );
        expect(closedResult, isA<CommercialServiceDetailLoaded>());
        final closedLoaded = closedResult as CommercialServiceDetailLoaded;
        expect(
          closedLoaded.noticeMessage,
          equals(CommercialServiceMessages.msg75),
        );

        // Inactive POI (904)
        final inactiveResult = await repository.getServiceDetail(
          rawPoiId: '904',
          isDemoMode: true,
          demoScenario: DemoCommercialServiceScenario.inactivePoi,
        );
        expect(
          inactiveResult,
          isA<CommercialServiceDetailInactiveOrNotFound>(),
        );

        // System Failure (908)
        final failureResult = await repository.getServiceDetail(
          rawPoiId: '908',
          isDemoMode: true,
          demoScenario: DemoCommercialServiceScenario.systemFailure,
        );
        expect(failureResult, isA<CommercialServiceDetailFailure>());
      },
    );
  });
}
