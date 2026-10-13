import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class TripHistoryRepositoryImpl implements TripHistoryRepository {
  TripHistoryRepositoryImpl({
    DioClient? dioClient,
    DemoTripHistoryStore? demoStore,
    this.isDemoMode = false,
  }) : _dioClient = dioClient,
       _demoStore = demoStore ?? DemoTripHistoryStore();

  final DioClient? _dioClient;
  final DemoTripHistoryStore _demoStore;
  final bool isDemoMode;

  static const String _endpoint = '/api/v1/traveler/trips';

  @override
  Future<TripHistoryPageResult> getTrips({
    required int travelerId,
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

    final client = _dioClient;
    if (client == null) {
      throw const ServerFailure(TripHistoryStringsEn.errorMessageGeneric);
    }

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': status.name,
        if (type != null) 'type': type.name,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };

      final response = await client.dio.get<Map<String, dynamic>>(
        _endpoint,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data == null) {
        return const TripHistoryPageResult(
          items: [],
          totalCount: 0,
          page: 1,
          pageSize: 20,
        );
      }

      // If backend returns data, map it; otherwise fallback to empty result
      final itemsRaw = data['items'] as List<dynamic>? ?? [];
      final totalCount =
          (data['totalCount'] as num?)?.toInt() ?? itemsRaw.length;

      final items = itemsRaw.map((raw) {
        final m = raw as Map<String, dynamic>;
        return TripHistoryItem(
          id: m['id']?.toString() ?? '',
          bookingCode: m['bookingCode']?.toString() ?? '',
          title: m['title']?.toString() ?? '',
          type: TripType.values.firstWhere(
            (e) => e.name == m['type'],
            orElse: () => TripType.tour,
          ),
          status: TripStatus.values.firstWhere(
            (e) => e.name == m['status'],
            orElse: () => TripStatus.upcoming,
          ),
          departureDate:
              DateTime.tryParse(m['departureDate']?.toString() ?? '') ??
              DateTime.now(),
          participantsCount: (m['participantsCount'] as num?)?.toInt() ?? 1,
          totalAmount: (m['totalAmount'] as num?)?.toInt() ?? 0,
          travelerId: travelerId,
          hasEticket: m['hasEticket'] == true,
        );
      }).toList();

      return TripHistoryPageResult(
        items: items,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 404 || e.response == null)) {
        // Backend endpoint not yet implemented on develop (NO_BACKEND)
        throw const ServerFailure(TripHistoryStringsEn.errorMessageGeneric);
      }
      throw ErrorMapper.toFailure(e);
    }
  }

  @override
  Future<TripHistoryItem?> getTripById({
    required int travelerId,
    required String tripId,
  }) async {
    if (isDemoMode) {
      return _demoStore.getTripById(travelerId: travelerId, tripId: tripId);
    }

    final client = _dioClient;
    if (client == null) {
      throw const ServerFailure(TripHistoryStringsEn.errorMessageGeneric);
    }

    try {
      final response = await client.dio.get<Map<String, dynamic>>(
        '$_endpoint/$tripId',
      );
      final m = response.data;
      if (m == null) return null;

      return TripHistoryItem(
        id: m['id']?.toString() ?? '',
        bookingCode: m['bookingCode']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        type: TripType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => TripType.tour,
        ),
        status: TripStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => TripStatus.upcoming,
        ),
        departureDate:
            DateTime.tryParse(m['departureDate']?.toString() ?? '') ??
            DateTime.now(),
        participantsCount: (m['participantsCount'] as num?)?.toInt() ?? 1,
        totalAmount: (m['totalAmount'] as num?)?.toInt() ?? 0,
        travelerId: travelerId,
        hasEticket: m['hasEticket'] == true,
      );
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 404 || e.response == null)) {
        throw const NotFoundFailure('The requested trip could not be found.');
      }
      throw ErrorMapper.toFailure(e);
    }
  }
}
