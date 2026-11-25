import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/commercial_booking_repository.dart';

final class CommercialBookingApi implements CommercialBookingRepository {
  const CommercialBookingApi(this.client);

  final DioClient client;

  @override
  Future<List<CommercialOption>> options(int poiId) async {
    try {
      final response = await client.dio.get<List<dynamic>>(
        '/api/v1/commercial-services/poi/$poiId/options',
      );
      return response.data!
          .cast<Map<String, dynamic>>()
          .map(
            (item) => (
              id: item['id'] as int,
              name: item['name'] as String,
              priceAmount: item['priceAmount'] as num,
            ),
          )
          .toList();
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<List<CommercialSlot>> availability(int serviceId) async {
    try {
      final response = await client.dio.get<List<dynamic>>(
        '/api/v1/commercial-services/$serviceId/availability',
      );
      return response.data!
          .cast<Map<String, dynamic>>()
          .map(
            (item) => (
              startsAt: DateTime.parse(item['startsAt'] as String),
              remainingQuantity: item['remainingQuantity'] as int,
            ),
          )
          .where((slot) => slot.remainingQuantity > 0)
          .toList();
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<CommercialBookingReceipt> submit(
    CommercialBookingRequest request,
    String key,
  ) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        '/api/v1/traveler/service-booking-requests',
        data: {
          'serviceId': request.serviceId,
          'startsAt': request.startsAt.toUtc().toIso8601String(),
          'quantity': request.quantity,
          'contactName': request.contactName,
          'contactPhone': request.contactPhone,
          'contactEmail': request.contactEmail,
          'specialRequest': request.specialRequest,
          'itineraryId': ?request.itineraryId,
        },
        options: Options(headers: {'Idempotency-Key': key}),
      );
      final data = response.data!;
      return (
        requestCode: data['requestCode'] as String,
        status: data['status'] as String,
        estimatedAmount: data['estimatedAmount'] as num,
      );
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 409) {
        final data = error.response?.data;
        final code = data is Map<String, dynamic> ? data['errorCode'] : null;
        if (code == 'MSG70' || code == 'MSG71') {
          throw const ConflictFailure(
            'Khung giờ hoặc số lượng đã thay đổi. Hãy làm mới lịch và chọn lại.',
          );
        }
      }
      throw ErrorMapper.toFailure(error);
    }
  }
}
