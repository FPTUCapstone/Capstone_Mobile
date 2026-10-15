import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/canonical_trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/canonical_trip_review_repository.dart';

final class CanonicalTripReviewRepositoryImpl
    implements CanonicalTripReviewRepository {
  const CanonicalTripReviewRepositoryImpl(this._client);
  final DioClient _client;
  String _path(ReviewableRecordRef ref) =>
      '/api/v1/${ref.apiSegment}/${ref.id}/review';

  @override
  Future<CanonicalReviewContext> getContext(ReviewableRecordRef ref) async {
    try {
      return _context(
        (await _client.dio.get<Map<String, dynamic>>(_path(ref))).data!,
        ref,
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CanonicalTripReview> create(
    ReviewableRecordRef ref, {
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required List<ReviewPhotoUpload> photos,
  }) async {
    final metadata = jsonEncode({
      'overallRating': rating,
      'title': title,
      'content': content,
      'poiRatings': <Object>[],
      'routePacing': null,
      'cspRating': null,
      'publishDisplayName': publishDisplayName,
    });
    final form = FormData.fromMap({
      'metadata': MultipartFile.fromString(
        metadata,
        filename: 'metadata.json',
        contentType: DioMediaType.parse('application/json'),
      ),
      'files': [
        for (final photo in photos)
          MultipartFile.fromBytes(
            photo.bytes,
            filename: photo.name,
            contentType: DioMediaType.parse(photo.contentType),
          ),
      ],
    });
    try {
      return _review(
        (await _client.dio.post<Map<String, dynamic>>(
          _path(ref),
          data: form,
        )).data!,
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CanonicalTripReview> update(
    ReviewableRecordRef ref, {
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required String version,
  }) async {
    try {
      return _review(
        (await _client.dio.put<Map<String, dynamic>>(
          _path(ref),
          data: {
            'overallRating': rating,
            'title': title,
            'content': content,
            'publishDisplayName': publishDisplayName,
            'version': version,
          },
        )).data!,
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  CanonicalReviewContext _context(
    Map<String, dynamic> json,
    ReviewableRecordRef ref,
  ) {
    final summary = json['summary'] as Map<String, dynamic>?;
    final reviewJson = json['review'] as Map<String, dynamic>?;
    return CanonicalReviewContext(
      reference: ref,
      bookingStatus: json['bookingStatus'] as String,
      name: summary?['name'] as String? ?? '',
      departureAtUtc: DateTime.parse(
        summary?['departureAtUtc'] as String,
      ).toUtc(),
      bookingReference: summary?['bookingReference'] as String? ?? '',
      canSubmit: json['canSubmit'] as bool? ?? false,
      submitUnavailableReason: json['submitUnavailableReason'] as String?,
      existingReviewKind: json['existingReviewKind'] as String,
      review: reviewJson?['kind'] == 'new' ? _review(reviewJson!) : null,
      editableFields: (json['editableFields'] as List<dynamic>? ?? [])
          .cast<String>(),
    );
  }

  CanonicalTripReview _review(Map<String, dynamic> json) => CanonicalTripReview(
    id: (json['reviewId'] as num).toInt(),
    rating: (json['overallRating'] as num).toInt(),
    title: json['title'] as String,
    content: json['content'] as String,
    publishDisplayName: json['publishDisplayName'] as bool,
    createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
    editDeadlineUtc: DateTime.parse(json['editDeadlineUtc'] as String).toUtc(),
    version: json['version'] as String,
    mediaUrls: ((json['media'] as List<dynamic>? ?? []).map(
      (item) => (item as Map<String, dynamic>)['deliveryUrl'] as String,
    )).toList(),
  );

  Failure _failure(DioException error) {
    final data = error.response?.data;
    final code = data is Map<String, dynamic>
        ? data['errorCode'] as String?
        : null;
    final status = error.response?.statusCode;
    if (status == 401) return const AuthenticationFailure();
    if (status == 403) return const PermissionFailure();
    if (status == 404) return const NotFoundFailure();
    if (status == 409) return ConflictFailure(code ?? 'trip_review.conflict');
    if (status == 400 || status == 413 || status == 415) {
      return ValidationFailure(code ?? 'trip_review.invalid_input');
    }
    if (code == 'trip_review.policy_unavailable') {
      return const ServerFailure('trip_review.policy_unavailable');
    }
    return ServerFailure(code ?? 'The review service is unavailable.');
  }
}
