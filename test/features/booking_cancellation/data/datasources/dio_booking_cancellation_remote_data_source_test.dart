import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/data/datasources/booking_cancellation_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';

final class _Storage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => 'token';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}

final class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, String? body, this.error})
    : body = body ?? jsonEncode(_previewBody());

  int status;
  String body;
  DioException Function(RequestOptions options)? error;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final failure = error;
    if (failure != null) throw failure(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _previewBody({
  bool canCancel = true,
  String? blockingReasonCode,
  String? blockingReason,
  double estimatedRefundAmount = 300000,
  String refundStatus = 'Pending',
}) => {
  'bookingId': 42,
  'tourTitle': 'Hoi An Lantern Tour',
  'bookingStatus': 'Confirmed',
  'paymentStatus': 'Paid',
  'totalAmount': 1000000,
  'canCancel': canCancel,
  'blockingReasonCode': blockingReasonCode,
  'blockingReason': blockingReason,
  'estimatedRefundAmount': estimatedRefundAmount,
  'refundStatus': refundStatus,
};

String _problem(String code) => jsonEncode({
  'title': 'internal',
  'detail': 'SELECT secret',
  'errorCode': code,
});

({DioBookingCancellationRemoteDataSource dataSource, _Adapter adapter}) _build(
  _Adapter adapter,
) {
  final client = DioClient(
    config: AppConfig(
      environment: Environment.development,
      apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
    ),
    secureStorage: _Storage(),
  );
  // Without the auth interceptor a 401 never starts a real token refresh.
  client.dio.interceptors.clear();
  client.dio.httpClientAdapter = adapter;
  return (
    dataSource: DioBookingCancellationRemoteDataSource(client),
    adapter: adapter,
  );
}

Future<BookingCancellationFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on BookingCancellationFailure catch (failure) {
    return failure;
  }
  fail('expected a BookingCancellationFailure');
}

void main() {
  test('reads the cancellation preview', () async {
    final built = _build(_Adapter());

    final preview = await built.dataSource.getPreview(42);

    expect(built.adapter.requests.single.method, 'GET');
    expect(
      built.adapter.requests.single.path,
      '/api/v1/bookings/42/cancellation-preview',
    );
    expect(preview.bookingId, 42);
    expect(preview.canCancel, true);
    expect(preview.estimatedRefundAmount, 300000);
    expect(preview.blockingReasonCode, isNull);
  });

  test(
    'reads a preview that requires confirmation for a zero-percent refund',
    () async {
      final built = _build(
        _Adapter(
          body: jsonEncode(
            _previewBody(
              blockingReasonCode: 'booking.cancellation.confirmation_required',
              blockingReason: 'Cancelling within 72 hours refunds nothing.',
              estimatedRefundAmount: 0,
            ),
          ),
        ),
      );

      final preview = await built.dataSource.getPreview(42);

      expect(preview.canCancel, true);
      expect(
        preview.blockingReasonCode,
        'booking.cancellation.confirmation_required',
      );
      expect(preview.estimatedRefundAmount, 0);
    },
  );

  test('posts the cancellation with the idempotency key and body', () async {
    final built = _build(_Adapter(status: 200, body: '{}'));

    await built.dataSource.cancel(
      42,
      reasonCategory: 'ChangeOfPlans',
      reasonDetail: 'Cannot travel',
      confirmed: true,
      idempotencyKey: '3f1c2a7e-4b8d-4e6f-9a1b-2c3d4e5f6a7b',
    );

    final request = built.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/bookings/42/cancellation');
    expect(
      request.headers['Idempotency-Key'],
      '3f1c2a7e-4b8d-4e6f-9a1b-2c3d4e5f6a7b',
    );
    expect(request.data, {
      'reasonCategory': 'ChangeOfPlans',
      'reasonDetail': 'Cannot travel',
      'confirmed': true,
    });
  });

  final mapped = <String, (int, String, BookingCancellationFailureKind)>{
    'unauthorized': (
      401,
      _problem('booking.cancellation.unauthorized'),
      BookingCancellationFailureKind.signIn,
    ),
    'forbidden': (
      403,
      _problem('booking.cancellation.forbidden'),
      BookingCancellationFailureKind.forbidden,
    ),
    'not found': (
      404,
      _problem('booking.not_found'),
      BookingCancellationFailureKind.notFound,
    ),
    'invalid state': (
      409,
      _problem('booking.cancellation.invalid_state'),
      BookingCancellationFailureKind.invalidState,
    ),
    'reason required': (
      422,
      _problem('booking.cancellation.reason_required'),
      BookingCancellationFailureKind.reasonRequired,
    ),
    'confirmation required': (
      422,
      _problem('booking.cancellation.confirmation_required'),
      BookingCancellationFailureKind.confirmationRequired,
    ),
    'payment not refundable': (
      409,
      _problem('booking.cancellation.payment_not_refundable'),
      BookingCancellationFailureKind.paymentNotRefundable,
    ),
    'window closed': (
      422,
      _problem('booking.cancellation.window_closed'),
      BookingCancellationFailureKind.windowClosed,
    ),
    'idempotency mismatch': (
      409,
      _problem('booking.cancellation.idempotency_payload_mismatch'),
      BookingCancellationFailureKind.idempotencyMismatch,
    ),
    'an unrecognized error code': (
      409,
      _problem('booking.something_new'),
      BookingCancellationFailureKind.system,
    ),
    'a server error with no JSON body': (
      500,
      '<html>oops</html>',
      BookingCancellationFailureKind.system,
    ),
  };

  for (final entry in mapped.entries) {
    test('maps ${entry.key} to its failure kind', () async {
      final (status, body, expectedKind) = entry.value;
      final built = _build(_Adapter(status: status, body: body));

      final failure = await _failureOf(
        built.dataSource.cancel(
          42,
          confirmed: false,
          idempotencyKey: '3f1c2a7e-4b8d-4e6f-9a1b-2c3d4e5f6a7b',
        ),
      );

      expect(failure.kind, expectedKind);
    });
  }

  test('maps a connection error to a system failure', () async {
    final built = _build(
      _Adapter(
        error: (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'secret detail',
        ),
      ),
    );

    final failure = await _failureOf(built.dataSource.getPreview(42));

    expect(failure.kind, BookingCancellationFailureKind.system);
  });

  test(
    'maps a preview body that breaks the contract to a system failure',
    () async {
      final built = _build(_Adapter(body: '{"bookingId":42}'));

      final failure = await _failureOf(built.dataSource.getPreview(42));

      expect(failure.kind, BookingCancellationFailureKind.system);
    },
  );
}
