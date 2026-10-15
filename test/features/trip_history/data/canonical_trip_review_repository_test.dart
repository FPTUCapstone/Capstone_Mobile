import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/canonical_trip_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';

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
  const _Adapter(this.body);
  final String body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  Map<String, dynamic> validResponse() => {
    'bookingStatus': 'Completed',
    'summary': {
      'name': 'Hoi An',
      'departureAtUtc': '2026-10-01T02:00:00Z',
      'bookingReference': 'BK-7',
    },
    'canSubmit': false,
    'submitUnavailableReason': null,
    'existingReviewKind': 'new',
    'editableFields': ['overallRating', 'title', 'content'],
    'review': {
      'kind': 'new',
      'reviewId': 2,
      'overallRating': 5,
      'title': 'Great',
      'content': 'Excellent',
      'publishDisplayName': true,
      'publicationStatus': 'Published',
      'createdAtUtc': '2026-10-01T02:00:00Z',
      'editDeadlineUtc': '2026-10-08T02:00:00Z',
      'version': 'v1',
      'media': [
        {'deliveryUrl': 'https://example.test/review.jpg'},
      ],
    },
  };

  Future<void> expectInvalid(Map<String, dynamic> payload) async {
    final client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
      ),
      secureStorage: _Storage(),
    );
    client.dio.httpClientAdapter = _Adapter(jsonEncode(payload));
    final repository = CanonicalTripReviewRepositoryImpl(client);
    await expectLater(
      repository.getContext(
        const ReviewableRecordRef(
          kind: ReviewableRecordKind.commerceBooking,
          id: 7,
        ),
      ),
      throwsA(
        isA<ServerFailure>().having(
          (failure) => failure.message,
          'message',
          'trip_review.invalid_response',
        ),
      ),
    );
  }

  test('valid canonical response is parsed', () async {
    final client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
      ),
      secureStorage: _Storage(),
    );
    client.dio.httpClientAdapter = _Adapter(jsonEncode(validResponse()));
    final result = await CanonicalTripReviewRepositoryImpl(client).getContext(
      const ReviewableRecordRef(
        kind: ReviewableRecordKind.commerceBooking,
        id: 7,
      ),
    );
    expect(result.review?.version, 'v1');
    expect(result.review?.mediaUrls, ['https://example.test/review.jpg']);
  });

  test('invalid summary and timestamp fail closed', () async {
    final missingSummary = validResponse()..remove('summary');
    await expectInvalid(missingSummary);
    final invalidTimestamp = validResponse();
    (invalidTimestamp['summary'] as Map<String, dynamic>)['departureAtUtc'] =
        'not-a-date';
    await expectInvalid(invalidTimestamp);
  });

  test('incorrect booking and review status fail closed', () async {
    final invalidBookingStatus = validResponse()..['bookingStatus'] = 7;
    await expectInvalid(invalidBookingStatus);
    final invalidReviewStatus = validResponse();
    (invalidReviewStatus['review']
            as Map<String, dynamic>)['publicationStatus'] =
        'Draft';
    await expectInvalid(invalidReviewStatus);
  });

  test('invalid version and malformed media fail closed', () async {
    final invalidVersion = validResponse();
    (invalidVersion['review'] as Map<String, dynamic>)['version'] = '';
    await expectInvalid(invalidVersion);
    final invalidMedia = validResponse();
    (invalidMedia['review'] as Map<String, dynamic>)['media'] = [
      {'deliveryUrl': 12},
    ];
    await expectInvalid(invalidMedia);
  });
}
