import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/data/datasources/tour_recommendations_data_source.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_query.dart';

void main() {
  test(
    'production source reports pending integration without demo data',
    () async {
      const source = PendingTourRecommendationsDataSource();

      final result = await source.fetchCandidates(
        const TourRecommendationsQuery(),
      );

      expect(result, isA<TourRecommendationCandidatesPending>());
    },
  );

  test('demo source contains only English fixture copy', () async {
    const source = DemoTourRecommendationsDataSource();

    final result = await source.fetchCandidates(
      const TourRecommendationsQuery(),
    );
    final candidates = (result as TourRecommendationCandidatesAvailable).items;

    expect(candidates, isNotEmpty);
    expect(
      candidates.map((item) => item.tour.title).join(),
      isNot(contains('Đ')),
    );
    expect(
      candidates.expand((item) => item.matchReasons).join(),
      isNot(contains('Phù hợp')),
    );
  });

  group('DioTourRecommendationsDataSource', () {
    late DioClient client;
    late DioTourRecommendationsDataSource source;

    setUp(() {
      client = DioClient(
        config: AppConfig(
          environment: Environment.development,
          apiBaseUrl: Uri.parse('https://api.test.invalid'),
        ),
        secureStorage: _TokenStorage(),
      );
      source = DioTourRecommendationsDataSource(client);
    });

    test(
      'GET without snapshot triggers one POST refresh and parses D7 []',
      () async {
        final adapter = _QueueAdapter([
          _Response(_page(criteria: null, items: const [])),
          _Response(_page(criteria: _criteria(), items: [_item(80.01)])),
        ]);
        client.dio.httpClientAdapter = adapter;

        final result = await source.fetchCandidates(
          const TourRecommendationsQuery(),
        );

        expect(adapter.requests.map((r) => r.method), ['GET', 'POST']);
        expect(adapter.requests[0].queryParameters['page'], 1);
        final page = result as TourRecommendationCandidatesAvailable;
        expect(page.items.single.matchingScore, 80.01);
        expect(page.items.single.matchReasons, isEmpty);
        expect(page.items.single.tour.remainingSlots, 1);
      },
    );

    test('concurrent explicit refreshes share one POST', () async {
      final adapter = _QueueAdapter([
        _Response(
          _page(criteria: _criteria(), items: [_item(90)]),
          delay: const Duration(milliseconds: 20),
        ),
      ]);
      client.dio.httpClientAdapter = adapter;
      const query = TourRecommendationsQuery(refresh: true);

      await Future.wait([
        source.fetchCandidates(query),
        source.fetchCandidates(query),
      ]);

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'POST');
    });

    test('strictly rejects 80.00 and accepts 80.01', () async {
      client.dio.httpClientAdapter = _QueueAdapter([
        _Response(_page(criteria: _criteria(), items: [_item(80.00)])),
      ]);
      await expectLater(
        source.fetchCandidates(const TourRecommendationsQuery()),
        throwsA(isA<FormatException>()),
      );

      final accepting = DioTourRecommendationsDataSource(client);
      client.dio.httpClientAdapter = _QueueAdapter([
        _Response(_page(criteria: _criteria(), items: [_item(80.01)])),
      ]);
      final result = await accepting.fetchCandidates(
        const TourRecommendationsQuery(),
      );
      expect(
        (result as TourRecommendationCandidatesAvailable).items,
        hasLength(1),
      );
    });

    test('422 stable interest-tag code becomes no-preferences state', () async {
      client.dio.httpClientAdapter = _QueueAdapter([
        _Response({
          'errorCode': 'tour_recommendation.interest_tags_required',
        }, statusCode: 422),
      ]);

      final result = await source.fetchCandidates(
        const TourRecommendationsQuery(refresh: true),
      );

      expect(result, isA<TourRecommendationCandidatesNoPreferences>());
    });
  });
}

Map<String, Object?> _criteria() => {
  'destination': null,
  'startDate': null,
  'endDate': null,
  'minBudget': null,
  'maxBudget': null,
};

Map<String, Object?> _page({
  required Object? criteria,
  required List<Map<String, Object?>> items,
}) => {
  'page': 1,
  'pageSize': 20,
  'totalCount': items.length,
  'totalPages': items.isEmpty ? 0 : 1,
  'asOfUtc': '2026-11-13T00:00:00Z',
  'criteria': criteria,
  'items': items,
};

Map<String, Object?> _item(double score) => {
  'tour': {
    'tourId': '10',
    'title': 'Hoi An',
    'destinations': ['Hoi An'],
    'operatorName': 'TripMate',
    'durationDays': 2,
    'basePrice': 800000,
    'currency': 'VND',
    'representativeScheduleId': '20',
    'departureAtUtc': '2026-12-01T00:00:00Z',
    'availabilityStatus': 'available',
    'remainingSlots': 1,
    'thumbnailUrl': null,
    'aggregateRating': null,
  },
  'matchingScore': score,
  'matchingReasons': <Object?>[],
};

final class _Response {
  const _Response(
    this.body, {
    this.statusCode = 200,
    this.delay = Duration.zero,
  });
  final Object body;
  final int statusCode;
  final Duration delay;
}

final class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);
  final List<_Response> responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (responses.isEmpty) throw StateError('Unexpected request.');
    final response = responses.removeAt(0);
    if (response.delay > Duration.zero) {
      await Future<void>.delayed(response.delay);
    }
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _TokenStorage implements SecureStorageService {
  @override
  Future<String?> read(String key) async =>
      key == AppConstants.accessTokenKey ? 'traveler-token' : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}
