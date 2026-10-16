import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/mapbox_search_box_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';

import '../models/mapbox_search_box_model_test.dart';

void main() {
  late _Recorder mapbox;
  late MapboxSearchBoxRepositoryImpl repository;
  late int sessions;

  setUp(() {
    sessions = 0;
    mapbox = _Recorder((options) {
      if (options.path.contains('/retrieve/')) {
        return (
          200,
          {
            'features': [searchBoxFeature()],
          },
        );
      }
      return (
        200,
        {
          'suggestions': [searchBoxSuggestion()],
        },
      );
    });
    repository = MapboxSearchBoxRepositoryImpl(
      accessToken: 'pk.test-token',
      dio: Dio(BaseOptions(baseUrl: 'https://api.mapbox.com'))
        ..httpClientAdapter = mapbox,
      newSessionToken: () => 'session-${++sessions}',
    );
  });

  test('suggests Vietnamese locations near the traveler', () async {
    final candidates = await repository.suggest(
      ' dai hoc fpt ',
      near: const DeviceLocation(latitude: 16.0544, longitude: 108.2022),
    );

    final request = mapbox.requests.single;
    expect(request.path, '/search/searchbox/v1/suggest');
    expect(request.queryParameters, {
      'q': 'dai hoc fpt',
      'country': 'vn',
      'language': 'vi',
      'limit': MapboxSearchBoxRepositoryImpl.resultLimit,
      'types': MapboxSearchBoxRepositoryImpl.resultTypes,
      'proximity': '108.2022,16.0544',
      'session_token': 'session-1',
      'access_token': 'pk.test-token',
    });
    expect(candidates.single.name, 'Đại học FPT Đà Nẵng');
  });

  test('the picked suggestion is resolved in the same session', () async {
    final candidates = await repository.suggest('dai hoc fpt');
    final place = await repository.resolve(candidates.single);
    await repository.suggest('bach dang');

    expect(
      mapbox.requests[1].path,
      '/search/searchbox/v1/retrieve/poi.fpt-da-nang',
    );
    expect(mapbox.requests.map((r) => r.queryParameters['session_token']), [
      'session-1',
      'session-1',
      'session-2',
    ]);
    expect(place.latitude, 15.96862121);
  });

  test('a blank query does not call Mapbox', () async {
    expect(await repository.suggest('   '), isEmpty);
    expect(mapbox.requests, isEmpty);
  });

  test('a Mapbox error becomes a safe failure', () async {
    mapbox.handler = (_) => (401, {'message': 'Not Authorized'});

    await expectLater(
      repository.suggest('Hội An'),
      throwsA(
        isA<ServerFailure>().having(
          (failure) => failure.message,
          'message',
          'Address search is unavailable right now.',
        ),
      ),
    );
  });

  test('a place without a location is a safe failure', () async {
    mapbox.handler = (_) => (200, {'features': <Object>[]});

    await expectLater(
      repository.resolve(
        const AddressCandidate(id: 'poi.x', name: 'X', fullAddress: 'X'),
      ),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('the unavailable repository suggests nothing', () async {
    const unavailable = UnavailableAddressSearchRepository();

    expect(unavailable.isAvailable, isFalse);
    expect(await unavailable.suggest('Hội An'), isEmpty);
  });
}

final class _Recorder implements HttpClientAdapter {
  _Recorder(this.handler);

  (int, Object) Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
