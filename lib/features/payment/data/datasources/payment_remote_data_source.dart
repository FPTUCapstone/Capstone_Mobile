import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/payment/data/models/payment_models.dart';
import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';

abstract interface class PaymentRemoteDataSource {
  Future<PaymentLink> createOrReusePayment(String bookingId);

  Future<BookingPaymentStatus> getBookingPaymentStatus(String bookingId);

  Future<void> cancelPayment(String bookingId);

  Future<PaymentTransactionStatus> completeMockPayment({
    required int paymentId,
    required String outcome,
  });
}

final class DioPaymentRemoteDataSource implements PaymentRemoteDataSource {
  DioPaymentRemoteDataSource(DioClient client) : _dio = client.dio;
  final Dio _dio;

  @override
  Future<PaymentLink> createOrReusePayment(String bookingId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/traveler/bookings/$bookingId/payments',
    );
    final data = response.data?['data'] is Map<String, dynamic>
        ? response.data!['data'] as Map<String, dynamic>
        : response.data ?? <String, dynamic>{};
    return parsePaymentLink(data);
  }

  @override
  Future<BookingPaymentStatus> getBookingPaymentStatus(String bookingId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/traveler/bookings/$bookingId/payment',
    );
    final data = response.data?['data'] is Map<String, dynamic>
        ? response.data!['data'] as Map<String, dynamic>
        : response.data ?? <String, dynamic>{};
    return parseBookingPaymentStatus(data);
  }

  @override
  Future<void> cancelPayment(String bookingId) async {
    await _dio.post<void>(
      '/api/v1/traveler/bookings/$bookingId/payment/cancel',
    );
  }

  @override
  Future<PaymentTransactionStatus> completeMockPayment({
    required int paymentId,
    required String outcome,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/traveler/payments/$paymentId/mock-outcome',
      data: {'outcome': outcome},
    );
    final data = response.data?['data'] is Map<String, dynamic>
        ? response.data!['data'] as Map<String, dynamic>
        : response.data ?? <String, dynamic>{};
    return parsePaymentStatus(data['status']?.toString());
  }
}
