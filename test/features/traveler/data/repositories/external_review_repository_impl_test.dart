import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/external_review_repository_impl.dart';

void main() {
  late DioClient dioClient;
  late ExternalReviewRepositoryImpl repository;

  _Adapter respond(Object body, {int statusCode = 200}) {
    final adapter = _Adapter(body: jsonEncode(body), statusCode: statusCode);
    dioClient.dio.httpClientAdapter = adapter;
    return adapter;
  }

  setUp(() {
    dioClient = DioClient(
      config: AppConfig(
        environment: Environment.production,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: const _EmptySecureStorage(),
    );
    repository = ExternalReviewRepositoryImpl(dioClient: dioClient);
  });

  test('loads the recent reviews of a place', () async {
    final adapter = respond({
      'poiId': 501,
      'translationAvailable': false,
      'source': 'Tripadvisor',
      'rating': 4.5,
      'reviewCount': 310,
      'ratingImageUrl': 'https://static.tacdn.com/img/4.5.svg',
      'url': 'https://www.tripadvisor.com/x',
      'reviews': <Object>[],
    });

    final reviews = await repository.getReviews(501);

    expect(adapter.request?.path, '/api/v1/pois/501/external-reviews');
    expect(adapter.request?.queryParameters, {'size': 5});
    expect(reviews.isAvailable, isTrue);
  });

  test('asks for a Vietnamese translation of one review', () async {
    final adapter = respond({
      'reviewId': 9001,
      'language': 'vi',
      'title': 'Ngon',
      'text': 'Rất ngon',
      'machineTranslated': true,
    });

    final translated = await repository.translate(poiId: 501, reviewId: 9001);

    expect(
      adapter.request?.path,
      '/api/v1/pois/501/external-reviews/9001/translation',
    );
    expect(adapter.request?.queryParameters, {'target': 'vi'});
    expect(translated.text, 'Rất ngon');
  });

  test('translation switched off is a failure', () async {
    respond({
      'errorCode': 'external_reviews.translation_unavailable',
    }, statusCode: 503);

    expect(
      repository.translate(poiId: 501, reviewId: 9001),
      throwsA(isA<Failure>()),
    );
  });
}

final class _Adapter implements HttpClientAdapter {
  _Adapter({required this.body, this.statusCode = 200});

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

final class _EmptySecureStorage implements SecureStorageService {
  const _EmptySecureStorage();

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
