import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';

abstract interface class BookingRefundRemoteDataSource {
  Future<BookingRefundProgress> getProgress(String bookingId);
}

final class DioBookingRefundRemoteDataSource
    implements BookingRefundRemoteDataSource {
  DioBookingRefundRemoteDataSource(DioClient client) : _dio = client.dio;
  final Dio _dio;

  @override
  Future<BookingRefundProgress> getProgress(String bookingId) async {
    final normalizedBookingId = int.tryParse(bookingId);
    if (normalizedBookingId == null || normalizedBookingId <= 0) {
      throw const FormatException('The booking id is invalid.');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/bookings/$normalizedBookingId/refund',
    );
    final envelope = response.data;
    final raw = envelope?['data'] is Map<String, dynamic>
        ? envelope!['data'] as Map<String, dynamic>
        : envelope;
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('The refund progress response is invalid.');
    }
    return _parseProgress(raw);
  }

  BookingRefundProgress _parseProgress(Map<String, dynamic> raw) {
    final bookingId = _int(raw['bookingId']);
    final bookingCode = raw['bookingCode']?.toString().trim();
    final amount = _int(raw['refundAmount']);
    final requestedAt = DateTime.tryParse(
      raw['requestedAtUtc']?.toString() ?? '',
    )?.toUtc();
    if (bookingId == null ||
        bookingId <= 0 ||
        bookingCode == null ||
        bookingCode.isEmpty ||
        amount == null ||
        amount < 0 ||
        requestedAt == null) {
      throw const FormatException('The refund progress response is invalid.');
    }
    return BookingRefundProgress(
      bookingId: bookingId,
      bookingCode: bookingCode,
      refundAmount: amount,
      status: BookingRefundStatus.fromWire(raw['status']?.toString()),
      attemptCount: _int(raw['attemptCount']) ?? 0,
      requestedAtUtc: requestedAt,
      gatewayReference: _nullableText(raw['gatewayReference']),
      processedAtUtc: _date(raw['processedAtUtc']),
      nextAttemptAtUtc: _date(raw['nextAttemptAtUtc']),
    );
  }

  static int? _int(Object? value) => switch (value) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
