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
    } on Object {
      throw const ServerFailure('trip_review.invalid_response');
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
    final form = buildCanonicalReviewMultipart(
      rating: rating,
      title: title,
      content: content,
      publishDisplayName: publishDisplayName,
      photos: photos,
    );
    try {
      return _review(
        (await _client.dio.post<Map<String, dynamic>>(
          _path(ref),
          data: form,
        )).data!,
      );
    } on DioException catch (error) {
      throw _failure(error);
    } on Object {
      throw const ServerFailure('trip_review.invalid_response');
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
    } on Object {
      throw const ServerFailure('trip_review.invalid_response');
    }
  }

  CanonicalReviewContext _context(
    Map<String, dynamic> json,
    ReviewableRecordRef ref,
  ) {
    final summary = json['summary'] as Map<String, dynamic>?;
    final departure = summary?['departureAtUtc'];
    final bookingStatus = json['bookingStatus'];
    final existingReviewKind = json['existingReviewKind'];
    final name = summary?['name'];
    final bookingReference = summary?['bookingReference'];
    final canSubmit = json['canSubmit'];
    final editableFields = json['editableFields'];
    if (summary == null ||
        departure is! String ||
        DateTime.tryParse(departure) == null ||
        bookingStatus is! String ||
        bookingStatus.isEmpty ||
        existingReviewKind is! String ||
        !const {'none', 'new', 'legacy'}.contains(existingReviewKind) ||
        name is! String ||
        name.isEmpty ||
        bookingReference is! String ||
        bookingReference.isEmpty ||
        canSubmit is! bool ||
        editableFields is! List<dynamic> ||
        editableFields.any((field) => field is! String)) {
      throw const ServerFailure('trip_review.invalid_response');
    }
    final reviewJson = json['review'] as Map<String, dynamic>?;
    if ((existingReviewKind == 'new' && reviewJson?['kind'] != 'new') ||
        (existingReviewKind == 'none' && reviewJson != null)) {
      throw const ServerFailure('trip_review.invalid_response');
    }
    return CanonicalReviewContext(
      reference: ref,
      bookingStatus: bookingStatus,
      name: name,
      departureAtUtc: DateTime.parse(departure).toUtc(),
      bookingReference: bookingReference,
      canSubmit: canSubmit,
      submitUnavailableReason: json['submitUnavailableReason'] as String?,
      existingReviewKind: existingReviewKind,
      review: reviewJson?['kind'] == 'new' ? _review(reviewJson!) : null,
      editableFields: editableFields.cast<String>(),
    );
  }

  CanonicalTripReview _review(Map<String, dynamic> json) {
    final id = json['reviewId'];
    final rating = json['overallRating'];
    final title = json['title'];
    final content = json['content'];
    final publishDisplayName = json['publishDisplayName'];
    final publicationStatus = json['publicationStatus'];
    final createdAt = json['createdAtUtc'];
    final editDeadline = json['editDeadlineUtc'];
    final version = json['version'];
    final media = json['media'];
    if (id is! int ||
        id <= 0 ||
        rating is! int ||
        rating < 1 ||
        rating > 5 ||
        title is! String ||
        title.isEmpty ||
        content is! String ||
        content.isEmpty ||
        publishDisplayName is! bool ||
        publicationStatus != 'Published' ||
        createdAt is! String ||
        DateTime.tryParse(createdAt) == null ||
        editDeadline is! String ||
        DateTime.tryParse(editDeadline) == null ||
        version is! String ||
        version.isEmpty ||
        media is! List<dynamic> ||
        media.any(
          (item) =>
              item is! Map<String, dynamic> ||
              item['deliveryUrl'] is! String ||
              (item['deliveryUrl'] as String).isEmpty,
        )) {
      throw const ServerFailure('trip_review.invalid_response');
    }
    return CanonicalTripReview(
      id: id,
      rating: rating,
      title: title,
      content: content,
      publishDisplayName: publishDisplayName,
      createdAtUtc: DateTime.parse(createdAt).toUtc(),
      editDeadlineUtc: DateTime.parse(editDeadline).toUtc(),
      version: version,
      mediaUrls: media
          .map(
            (item) => (item as Map<String, dynamic>)['deliveryUrl'] as String,
          )
          .toList(),
    );
  }

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
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure();
    }
    return ServerFailure(code ?? 'The review service is unavailable.');
  }
}

FormData buildCanonicalReviewMultipart({
  required int rating,
  required String title,
  required String content,
  required bool publishDisplayName,
  required List<ReviewPhotoUpload> photos,
}) {
  final metadata = jsonEncode({
    'overallRating': rating,
    'title': title,
    'content': content,
    'poiRatings': <Object>[],
    'routePacing': null,
    'cspRating': null,
    'publishDisplayName': publishDisplayName,
  });
  return FormData.fromMap({
    'metadata': MultipartFile.fromString(
      metadata,
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
}
