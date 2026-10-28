import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/e_ticket/data/repositories/e_ticket_repository_impl.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket_failure.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/get_e_ticket_use_case.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/refresh_e_ticket_qr_use_case.dart';

import 'e_ticket_json_test.dart' show ticketBody;

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
    : body = body ?? jsonEncode(ticketBody());

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

({ETicketRepositoryImpl repository, _Adapter adapter}) _build(
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
  return (repository: ETicketRepositoryImpl(client), adapter: adapter);
}

String _problem(String code, [Map<String, Object?> extra = const {}]) =>
    jsonEncode({
      'title': 'internal',
      'detail': 'SELECT secret',
      'errorCode': code,
      ...extra,
    });

Future<ETicketFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ETicketFailure catch (failure) {
    return failure;
  }
  fail('expected an ETicketFailure');
}

void main() {
  test('reads a ticket by ticket id', () async {
    final built = _build(_Adapter());

    final ticket = await GetETicketUseCase(built.repository)(
      const ETicketKey.ticket(77),
    );

    expect(ticket.ticketId, 77);
    expect(built.adapter.requests.single.method, 'GET');
    expect(built.adapter.requests.single.path, '/api/v1/traveler/tickets/77');
  });

  test('reads a ticket by booking id', () async {
    final built = _build(_Adapter());

    await GetETicketUseCase(built.repository)(const ETicketKey.booking(456));

    expect(
      built.adapter.requests.single.path,
      '/api/v1/traveler/bookings/456/ticket',
    );
  });

  test('refreshes the QR with a POST', () async {
    final built = _build(_Adapter());

    final ticket = await RefreshETicketQrUseCase(built.repository)(77);

    expect(ticket.qr?.content, 'TM1.token.signature');
    expect(built.adapter.requests.single.method, 'POST');
    expect(
      built.adapter.requests.single.path,
      '/api/v1/traveler/tickets/77/qr-code/refresh',
    );
  });

  final mapped = <String, (int, String, ETicketFailure)>{
    'unauthorized': (
      401,
      _problem('ticket.unauthorized'),
      const ETicketFailure(ETicketFailureKind.signIn),
    ),
    'forbidden': (
      403,
      _problem('ticket.forbidden'),
      const ETicketFailure(ETicketFailureKind.forbidden),
    ),
    'not found': (
      404,
      _problem('ticket.not_found'),
      const ETicketFailure(ETicketFailureKind.notFound),
    ),
    'not confirmed': (
      409,
      _problem('ticket.booking_not_confirmed'),
      const ETicketFailure(ETicketFailureKind.notConfirmed),
    ),
    'not issued': (
      409,
      _problem('ticket.not_issued'),
      const ETicketFailure(ETicketFailureKind.notIssued),
    ),
    'not refreshable': (
      409,
      _problem('ticket.not_refreshable', {'ticketStatus': 'Used'}),
      const ETicketFailure(
        ETicketFailureKind.notRefreshable,
        ticketStatus: ETicketStatus.used,
      ),
    ),
    'not refreshable with an unknown status': (
      409,
      _problem('ticket.not_refreshable', {'ticketStatus': 'Lost'}),
      const ETicketFailure(ETicketFailureKind.notRefreshable),
    ),
    'an unknown conflict': (
      409,
      _problem('booking.other'),
      const ETicketFailure(ETicketFailureKind.system),
    ),
    'a server error': (
      500,
      '<html>oops</html>',
      const ETicketFailure(ETicketFailureKind.system),
    ),
  };

  for (final entry in mapped.entries) {
    test('maps ${entry.key} to its failure', () async {
      final (status, body, expected) = entry.value;
      final built = _build(_Adapter(status: status, body: body));

      final failure = await _failureOf(built.repository.refreshQr(77));

      expect(failure, expected);
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

    final failure = await _failureOf(built.repository.getTicket(77));

    expect(failure, const ETicketFailure(ETicketFailureKind.system));
  });

  test('maps a body that breaks the contract to a system failure', () async {
    final built = _build(_Adapter(body: '{"ticketId":77}'));

    final failure = await _failureOf(built.repository.getTicket(77));

    expect(failure, const ETicketFailure(ETicketFailureKind.system));
  });
}
