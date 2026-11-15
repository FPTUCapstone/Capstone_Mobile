import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/data/datasources/partial_refund_proposal_remote_data_source.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';

void main() {
  late DioClient client;
  late DioPartialRefundProposalRemoteDataSource dataSource;

  setUp(() {
    client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: _EmptySecureStorage(),
    );
    dataSource = DioPartialRefundProposalRemoteDataSource(client);
  });

  test('reads the proposal of the complaint', () async {
    final adapter = _Adapter(
      jsonEncode({
        'complaintId': 501,
        'bookingId': 301,
        'bookingCode': 'BK-UC75',
        'proposedAmount': 500000.0,
        'responseDeadlineUtc': '2026-11-09T03:00:00+00:00',
        'status': 'AwaitingTravelerResponse',
        'canRespond': true,
      }),
    );
    client.dio.httpClientAdapter = adapter;

    final proposal = await dataSource.getProposal(501);

    expect(adapter.requests.single.method, 'GET');
    expect(
      adapter.requests.single.path,
      '/api/v1/traveler/complaints/501/partial-refund-proposal',
    );
    expect(
      proposal,
      PartialRefundProposal(
        complaintId: 501,
        bookingId: 301,
        bookingCode: 'BK-UC75',
        proposedAmount: 500000,
        responseDeadlineUtc: DateTime.utc(2026, 11, 9, 3),
        status: PartialRefundProposalStatus.awaitingTravelerResponse,
        canRespond: true,
      ),
    );
  });

  for (final decision in PartialRefundDecision.values) {
    test('sends ${decision.wireValue} and reads the recorded status', () async {
      final adapter = _Adapter(
        jsonEncode({
          'complaintId': 501,
          'status': decision == PartialRefundDecision.accept
              ? 'Approved'
              : 'Declined',
          'approvedAmount': decision == PartialRefundDecision.accept
              ? 500000
              : null,
          'respondedAtUtc': '2026-11-07T03:00:00Z',
        }),
      );
      client.dio.httpClientAdapter = adapter;

      final result = await dataSource.respond(501, decision);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(
        request.path,
        '/api/v1/traveler/complaints/501/partial-refund-proposal/response',
      );
      expect(request.data, {'decision': decision.wireValue});
      expect(
        result.status,
        decision == PartialRefundDecision.accept
            ? PartialRefundProposalStatus.approved
            : PartialRefundProposalStatus.declined,
      );
      expect(
        result.approvedAmount,
        decision == PartialRefundDecision.accept ? 500000 : null,
      );
    });
  }

  test('rejects an invalid complaint id without calling the API', () async {
    final adapter = _Adapter('{}');
    client.dio.httpClientAdapter = adapter;

    await expectLater(
      dataSource.getProposal(0),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      dataSource.respond(-1, PartialRefundDecision.accept),
      throwsA(isA<FormatException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('rejects an unknown status instead of guessing one', () async {
    client.dio.httpClientAdapter = _Adapter(
      jsonEncode({
        'complaintId': 501,
        'bookingId': 301,
        'bookingCode': 'BK-UC75',
        'proposedAmount': 500000,
        'responseDeadlineUtc': '2026-11-09T03:00:00Z',
        'status': 'CounterOffered',
        'canRespond': true,
      }),
    );

    await expectLater(
      dataSource.getProposal(501),
      throwsA(isA<FormatException>()),
    );
  });
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this._body);

  final String _body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      _body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _EmptySecureStorage implements SecureStorageService {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
