import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_preview.dart';

abstract interface class BookingCancellationRemoteDataSource {
  Future<BookingCancellationPreview> getPreview(int bookingId);

  Future<void> cancel(
    int bookingId, {
    String? reasonCategory,
    String? reasonDetail,
    required bool confirmed,
    required String idempotencyKey,
  });
}

final class DioBookingCancellationRemoteDataSource
    implements BookingCancellationRemoteDataSource {
  DioBookingCancellationRemoteDataSource(DioClient client) : _dio = client.dio;
  final Dio _dio;

  static const _bookings = '/api/v1/bookings';

  @override
  Future<BookingCancellationPreview> getPreview(int bookingId) async {
    final Map<String, dynamic> raw;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_bookings/$bookingId/cancellation-preview',
      );
      raw = _unwrap(response.data);
    } on DioException catch (error) {
      throw _failure(error);
    } on Object {
      throw const BookingCancellationFailure(
        BookingCancellationFailureKind.system,
      );
    }
    try {
      return _parsePreview(raw);
    } on Object {
      throw const BookingCancellationFailure(
        BookingCancellationFailureKind.system,
      );
    }
  }

  @override
  Future<void> cancel(
    int bookingId, {
    String? reasonCategory,
    String? reasonDetail,
    required bool confirmed,
    required String idempotencyKey,
  }) async {
    try {
      await _dio.post<Object?>(
        '$_bookings/$bookingId/cancellation',
        data: {
          'reasonCategory': reasonCategory,
          'reasonDetail': reasonDetail,
          'confirmed': confirmed,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
    } on DioException catch (error) {
      throw _failure(error);
    } on Object {
      throw const BookingCancellationFailure(
        BookingCancellationFailureKind.system,
      );
    }
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    return data is Map<String, dynamic> ? data : (envelope ?? const {});
  }

  BookingCancellationPreview _parsePreview(Map<String, dynamic> raw) {
    final bookingId = _int(raw['bookingId']);
    final tourTitle = raw['tourTitle']?.toString();
    final bookingStatus = raw['bookingStatus']?.toString();
    final paymentStatus = raw['paymentStatus']?.toString();
    final totalAmount = _double(raw['totalAmount']);
    final canCancel = raw['canCancel'];
    final estimatedRefundAmount = _double(raw['estimatedRefundAmount']);
    final refundStatus = raw['refundStatus']?.toString();
    if (bookingId == null ||
        tourTitle == null ||
        tourTitle.isEmpty ||
        bookingStatus == null ||
        bookingStatus.isEmpty ||
        paymentStatus == null ||
        paymentStatus.isEmpty ||
        totalAmount == null ||
        canCancel is! bool ||
        estimatedRefundAmount == null ||
        refundStatus == null ||
        refundStatus.isEmpty) {
      throw const FormatException(
        'The cancellation preview response is invalid.',
      );
    }
    return BookingCancellationPreview(
      bookingId: bookingId,
      tourTitle: tourTitle,
      bookingStatus: bookingStatus,
      paymentStatus: paymentStatus,
      totalAmount: totalAmount,
      canCancel: canCancel,
      blockingReasonCode: _nullableText(raw['blockingReasonCode']),
      blockingReason: _nullableText(raw['blockingReason']),
      estimatedRefundAmount: estimatedRefundAmount,
      refundStatus: refundStatus,
    );
  }

  /// Only reviewed codes become specific failures; no server text ever reaches the user.
  BookingCancellationFailure _failure(DioException error) {
    final status = error.response?.statusCode;
    final code = _problem(error.response?.data)['errorCode'];
    if (status == 401 || code == 'booking.cancellation.unauthorized') {
      return const BookingCancellationFailure(
        BookingCancellationFailureKind.signIn,
      );
    }
    if (status == 403 || code == 'booking.cancellation.forbidden') {
      return const BookingCancellationFailure(
        BookingCancellationFailureKind.forbidden,
      );
    }
    return switch (code) {
      'booking.not_found' => const BookingCancellationFailure(
        BookingCancellationFailureKind.notFound,
      ),
      'booking.cancellation.invalid_state' => const BookingCancellationFailure(
        BookingCancellationFailureKind.invalidState,
      ),
      'booking.cancellation.reason_required' =>
        const BookingCancellationFailure(
          BookingCancellationFailureKind.reasonRequired,
        ),
      'booking.cancellation.confirmation_required' =>
        const BookingCancellationFailure(
          BookingCancellationFailureKind.confirmationRequired,
        ),
      'booking.cancellation.payment_not_refundable' =>
        const BookingCancellationFailure(
          BookingCancellationFailureKind.paymentNotRefundable,
        ),
      'booking.cancellation.window_closed' => const BookingCancellationFailure(
        BookingCancellationFailureKind.windowClosed,
      ),
      'booking.cancellation.idempotency_payload_mismatch' =>
        const BookingCancellationFailure(
          BookingCancellationFailureKind.idempotencyMismatch,
        ),
      _ => const BookingCancellationFailure(
        BookingCancellationFailureKind.system,
      ),
    };
  }

  static Map<String, Object?> _problem(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is! String) return const {};
    try {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on Object {
      return const {};
    }
  }

  static int? _int(Object? value) => switch (value) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };

  static double? _double(Object? value) => switch (value) {
    double value => value,
    num value => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
