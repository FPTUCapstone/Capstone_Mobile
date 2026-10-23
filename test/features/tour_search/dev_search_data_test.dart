import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/tour_search/data/datasources/tour_search_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';

void main() {
  test('dev route sends canonical params and key only when enabled', () async {
    for (final environment in [
      Environment.development,
      Environment.production,
    ]) {
      final config = AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('http://127.0.0.1:5077'),
        devSearchV2: true,
        devSearchKey: 'test-only-key',
      );
      final client = DioClient(config: config, secureStorage: _Storage());
      final adapter = _Adapter();
      client.dio.httpClientAdapter = adapter;
      final source = DioTourSearchRemoteDataSource(client, config: config);
      await source.searchTours(
        const TourSearchQuery(keyword: 'biển', mode: 'semantic'),
      );
      final request = adapter.request!;
      if (environment == Environment.production) {
        expect(request.path, '/api/v1/tours');
        expect(request.headers.containsKey('X-TM70-Dev-Key'), isFalse);
        expect(request.queryParameters.containsKey('keyword'), isFalse);
      } else {
        expect(request.path, '/api/dev/tours/search');
        expect(request.cancelToken, isNotNull);
        expect(request.headers['X-TM70-Dev-Key'], 'test-only-key');
        expect(request.queryParameters['mode'], 'semantic');
        final categories = await source.loadCategories();
        expect(categories.single.code, 'server-code');
      }
      client.dio.close();
    }
  });
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      options.path.endsWith('categories')
          ? '[{"categoryId":"id","code":"server-code","name":"Server name"}]'
          : '{"page":1,"pageSize":20,"totalCount":0,"totalPages":0,"items":[]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Storage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}
