import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/data/datasources/post_trip_complaint_remote_data_source.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/post_trip_complaint.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/domain/entities/selected_evidence.dart';

void main() {
  late DioClient client;
  late DioPostTripComplaintRemoteDataSource dataSource;

  setUp(() {
    client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: _EmptySecureStorage(),
    );
    dataSource = DioPostTripComplaintRemoteDataSource(client);
  });

  group('amendEvidence (add evidence)', () {
    test('sends evidence multipart request with idempotency key and parses response JSON', () async {
      final adapter = _Adapter(
        jsonEncode({
          'complaintId': 101,
          'evidenceAmendmentUsedAtUtc': '2026-11-16T12:00:00Z',
          'evidenceCount': 3,
          'evidenceTotalBytes': 1500000,
          'isReplay': false,
        }),
      );
      client.dio.httpClientAdapter = adapter;

      final result = await dataSource.amendEvidence(
        bookingId: 42,
        idempotencyKey: '00000000-0000-0000-0000-000000000001',
        evidence: [
          SelectedEvidence(
            name: 'ticket.pdf',
            sizeBytes: 500000,
            contentType: 'application/pdf',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(
        request.path,
        '/api/v1/traveler/bookings/42/post-trip-complaint/evidence',
      );
      expect(request.headers['Idempotency-Key'], '00000000-0000-0000-0000-000000000001');
      expect(request.data, isA<FormData>());

      expect(
        result,
        PostTripComplaintEvidenceAmendment(
          complaintId: 101,
          evidenceAmendmentUsedAtUtc: DateTime.utc(2026, 11, 16, 12),
          evidenceCount: 3,
          evidenceTotalBytes: 1500000,
          isReplay: false,
        ),
      );
    });

    test('correctly parses replayed response and envelope format', () async {
      final adapter = _Adapter(
        jsonEncode({
          'data': {
            'complaintId': 101,
            'evidenceAmendmentUsedAtUtc': '2026-11-16T12:00:00Z',
            'evidenceCount': 4,
            'evidenceTotalBytes': 2000000,
            'isReplay': true,
          },
        }),
      );
      client.dio.httpClientAdapter = adapter;

      final result = await dataSource.amendEvidence(
        bookingId: 42,
        idempotencyKey: '00000000-0000-0000-0000-000000000001',
        evidence: [
          SelectedEvidence(
            name: 'photo.jpg',
            sizeBytes: 500000,
            contentType: 'image/jpeg',
            bytes: Uint8List.fromList([4, 5, 6]),
          ),
        ],
      );

      expect(result.complaintId, 101);
      expect(result.isReplay, isTrue);
      expect(result.evidenceCount, 4);
      expect(result.evidenceTotalBytes, 2000000);
      expect(result.evidenceAmendmentUsedAtUtc, DateTime.utc(2026, 11, 16, 12));
    });

    test('throws FormatException when response JSON is missing required fields', () async {
      final invalidResponses = [
        jsonEncode({
          // missing complaintId
          'evidenceAmendmentUsedAtUtc': '2026-11-16T12:00:00Z',
          'evidenceCount': 3,
          'evidenceTotalBytes': 1500000,
          'isReplay': false,
        }),
        jsonEncode({
          'complaintId': 101,
          // invalid date
          'evidenceAmendmentUsedAtUtc': 'not-a-date',
          'evidenceCount': 3,
          'evidenceTotalBytes': 1500000,
          'isReplay': false,
        }),
        jsonEncode({
          'complaintId': 101,
          'evidenceAmendmentUsedAtUtc': '2026-11-16T12:00:00Z',
          // missing evidenceCount
          'evidenceTotalBytes': 1500000,
          'isReplay': false,
        }),
        jsonEncode({
          'complaintId': 101,
          'evidenceAmendmentUsedAtUtc': '2026-11-16T12:00:00Z',
          'evidenceCount': 3,
          'evidenceTotalBytes': 1500000,
          // isReplay is not bool
          'isReplay': 'not-a-bool',
        }),
      ];

      for (final payload in invalidResponses) {
        client.dio.httpClientAdapter = _Adapter(payload);

        await expectLater(
          dataSource.amendEvidence(
            bookingId: 42,
            idempotencyKey: 'key',
            evidence: [
              SelectedEvidence(
                name: 'a.png',
                sizeBytes: 100,
                contentType: 'image/png',
                bytes: Uint8List.fromList([1]),
              ),
            ],
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects non-positive bookingId before sending request', () async {
      final adapter = _Adapter('{}');
      client.dio.httpClientAdapter = adapter;

      await expectLater(
        dataSource.amendEvidence(
          bookingId: 0,
          idempotencyKey: 'key',
          evidence: [],
        ),
        throwsA(isA<FormatException>()),
      );
      expect(adapter.requests, isEmpty);
    });
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
