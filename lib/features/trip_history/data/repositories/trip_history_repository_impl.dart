import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class TripHistoryRepositoryImpl implements TripHistoryRepository {
  TripHistoryRepositoryImpl({
    this.dioClient,
    DemoTripHistoryStore? demoStore,
    this.isDemoMode = false,
  }) : _demoStore = demoStore ?? DemoTripHistoryStore();

  final DioClient? dioClient;
  final DemoTripHistoryStore _demoStore;
  final bool isDemoMode;

  @override
  Future<TripHistoryPageResult> getTrips({
    int? travelerId,
    TripStatus? status,
    TripType? type,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (isDemoMode) {
      return _demoStore.getTrips(
        travelerId: travelerId,
        status: status,
        type: type,
        startDate: startDate,
        endDate: endDate,
        page: page,
        pageSize: pageSize,
      );
    }

    // Production: Backend develop has NO UC-32 endpoint (NO_BACKEND).
    // Truthfully report PENDING_BE_INTEGRATION without calling invented API endpoints.
    throw const ServerFailure(
      TripHistoryStringsEn.productionIntegrationPending,
    );
  }

  @override
  Future<TripHistoryItem?> getTripById({
    int? travelerId,
    required String tripId,
  }) async {
    if (isDemoMode) {
      return _demoStore.getTripById(travelerId: travelerId, tripId: tripId);
    }

    // Production: Backend develop has NO UC-32 endpoint.
    throw const ServerFailure(
      TripHistoryStringsEn.productionIntegrationPending,
    );
  }
}
