import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/itinerary_repository_impl.dart';

import '../models/itinerary_summary_model_test.dart';

void main() {
  late DioClient dioClient;
  late ItineraryRepositoryImpl repository;

  _RecordingHttpClientAdapter respond(Object body, {int statusCode = 200}) {
    final adapter = _RecordingHttpClientAdapter(
      body: jsonEncode(body),
      statusCode: statusCode,
    );
    dioClient.dio.httpClientAdapter = adapter;
    return adapter;
  }

  setUp(() {
    dioClient = DioClient(
      config: AppConfig(
        environment: Environment.production,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: const _EmptySecureStorageService(),
    );
    repository = ItineraryRepositoryImpl(dioClient: dioClient);
  });

  test('listMine requests the paged trip list', () async {
    final adapter = respond(
      itinerarySummaryPageJson([itinerarySummaryJson()], page: 2),
    );

    final page = await repository.listMine(page: 2, pageSize: 20);

    expect(adapter.request?.method, 'GET');
    expect(adapter.request?.path, '/api/v1/itineraries');
    expect(adapter.request?.queryParameters, {'page': 2, 'pageSize': 20});
    expect(page.items.single.itineraryId, 60014);
  });

  test('listMine maps an expired session to an auth failure', () async {
    respond({'title': 'Unauthorized'}, statusCode: 401);

    expect(repository.listMine(), throwsA(isA<AuthenticationFailure>()));
  });
}

final class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter({required this.body, this.statusCode = 200});

  final String body;
  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _EmptySecureStorageService implements SecureStorageService {
  const _EmptySecureStorageService();

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
