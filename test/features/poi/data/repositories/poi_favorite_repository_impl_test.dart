import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/poi/data/datasources/poi_favorite_remote_data_source.dart';
import 'package:trip_mate_mobile/features/poi/data/repositories/poi_favorite_repository_impl.dart';

/// The favorite calls through the real Dio client: unlike the public POI
/// reads they must carry the traveler's token.
void main() {
  late DioClient dioClient;
  late PoiFavoriteRepositoryImpl repository;

  _RecordingAdapter respond(Object body, {int statusCode = 200}) {
    final adapter = _RecordingAdapter(
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
      secureStorage: const _SignedInStorage(),
    );
    repository = PoiFavoriteRepositoryImpl(
      DioPoiFavoriteRemoteDataSource(dioClient),
    );
  });

  test('reads the favorite mark with the traveler token', () async {
    final adapter = respond({'poiId': 12, 'isFavorite': true});

    final isFavorite = await repository.isFavorite(12);

    expect(isFavorite, isTrue);
    expect(adapter.request?.method, 'GET');
    expect(adapter.request?.path, '/api/v1/pois/12/favorite');
    expect(adapter.request?.headers['Authorization'], 'Bearer traveler-token');
  });

  test(
    'turning the mark on sends an authenticated PUT without a body',
    () async {
      final adapter = respond({'poiId': 12, 'isFavorite': true});

      final saved = await repository.setFavorite(12, isFavorite: true);

      expect(saved, isTrue);
      expect(adapter.request?.method, 'PUT');
      expect(adapter.request?.path, '/api/v1/pois/12/favorite');
      expect(adapter.request?.data, isNull);
      expect(
        adapter.request?.headers['Authorization'],
        'Bearer traveler-token',
      );
    },
  );

  test(
    'turning the mark off sends an authenticated DELETE without a body',
    () async {
      final adapter = respond({'poiId': 12, 'isFavorite': false});

      final saved = await repository.setFavorite(12, isFavorite: false);

      expect(saved, isFalse);
      expect(adapter.request?.method, 'DELETE');
      expect(adapter.request?.path, '/api/v1/pois/12/favorite');
      expect(adapter.request?.data, isNull);
      expect(
        adapter.request?.headers['Authorization'],
        'Bearer traveler-token',
      );
    },
  );

  test('a place that no longer exists is a typed failure', () async {
    respond({'title': 'Not found'}, statusCode: 404);

    await expectLater(
      repository.setFavorite(999, isFavorite: true),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('a response without the mark is a failure, not a guess', () async {
    respond({'poiId': 12});

    await expectLater(repository.isFavorite(12), throwsA(isA<Failure>()));
  });
}

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.body, this.statusCode = 200});

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

final class _SignedInStorage implements SecureStorageService {
  const _SignedInStorage();

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async =>
      key == AppConstants.accessTokenKey ? 'traveler-token' : null;

  @override
  Future<void> write(String key, String value) async {}
}
