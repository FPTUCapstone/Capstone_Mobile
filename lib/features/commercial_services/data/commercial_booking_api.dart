import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/commercial_booking_repository.dart';

final class CommercialBookingApi implements CommercialBookingRepository {
  const CommercialBookingApi(this.client, this.storage);

  final DioClient client;
  final SecureStorageService storage;
  static const _requests = '/api/v1/traveler/service-booking-requests';

  @override
  Future<List<TravelerServiceRequest>> requests({int? beforeId}) async {
    try {
      final response = await client.dio.get<List<dynamic>>(
        _requests,
        queryParameters: {'beforeId': ?beforeId},
      );
      return response.data!
          .cast<Map<String, dynamic>>()
          .map(
            (item) => (
              id: item['id'] as int,
              requestCode: item['requestCode'] as String,
              serviceName: item['serviceName'] as String,
              status: item['status'] as String,
              startsAt: DateTime.parse(item['startsAt'] as String),
              quantity: item['quantity'] as int,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await client.dio.post<void>('$_requests/$id/cancel');
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

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
    final body = {
      'serviceId': request.serviceId,
      'startsAt': request.startsAt.toUtc().toIso8601String(),
      'quantity': request.quantity,
      'contactName': request.contactName,
      'contactPhone': request.contactPhone,
      'contactEmail': request.contactEmail.trim().toLowerCase(),
      'specialRequest': request.specialRequest,
      'itineraryId': ?request.itineraryId,
    };
    String? storageKey;
    String? effectiveKey;
    try {
      (storageKey, effectiveKey) = await storage.withSessionLock(() async {
        final token = await storage.read(AppConstants.accessTokenKey);
        final subject = _tokenSubject(token);
        if (subject == null) {
          throw const AuthenticationFailure(
            'Vui lòng đăng nhập lại để gửi yêu cầu.',
          );
        }
        final digest = sha256.convert(utf8.encode(jsonEncode([subject, body])));
        final storageKey = 'uc31_pending_$digest';
        final previous = await storage.read(storageKey);
        if (previous == null) await storage.write(storageKey, key);
        return (storageKey, previous ?? key);
      });
      final response = await client.dio.post<Map<String, dynamic>>(
        _requests,
        data: body,
        options: Options(headers: {'Idempotency-Key': effectiveKey}),
      );
      final data = response.data!;
      final receipt = (
        requestCode: data['requestCode'] as String,
        status: data['status'] as String,
        estimatedAmount: data['estimatedAmount'] as num,
      );
      await _forget(storageKey!, effectiveKey!);
      return receipt;
    } catch (error) {
      if (error is Failure) rethrow;
      if (error is DioException) {
        final status = error.response?.statusCode;
        if ((status == 400 || status == 404 || status == 409) &&
            storageKey != null &&
            effectiveKey != null) {
          await _forget(storageKey, effectiveKey);
        }
        final data = error.response?.data;
        final code = data is Map<String, dynamic> ? data['errorCode'] : null;
        if (code == 'MSG70' || code == 'MSG71') {
          throw const ConflictFailure(
            'Khung giờ hoặc số lượng đã thay đổi. Hãy làm mới lịch và chọn lại.',
          );
        }
        if (code == 'MSG75') {
          throw const ConflictFailure('Dịch vụ hiện không mở nhận yêu cầu.');
        }
        if (code == 'MSG76') {
          throw const ConflictFailure(
            'Ngày giờ đã qua. Hãy chọn một khung giờ khác.',
          );
        }
      }
      throw ErrorMapper.toFailure(error);
    }
  }

  Future<void> _forget(String storageKey, String effectiveKey) async {
    try {
      await storage.withSessionLock(() async {
        if (await storage.read(storageKey) == effectiveKey) {
          await storage.delete(storageKey);
        }
      });
    } catch (_) {
      // The server has already replied. Retaining the key allows safe replay.
    }
  }

  String? _tokenSubject(String? token) {
    if (token == null) return null;
    try {
      final payload = token.split('.')[1];
      final claims =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(payload))),
              )
              as Map<String, dynamic>;
      return claims['sub']?.toString();
    } catch (_) {
      return null;
    }
  }
}
