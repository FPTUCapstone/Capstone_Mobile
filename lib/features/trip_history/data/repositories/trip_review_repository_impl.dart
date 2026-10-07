import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class TripReviewRepositoryImpl implements TripReviewRepository {
  TripReviewRepositoryImpl({
    DioClient? dioClient,
    DemoTripHistoryStore? demoStore,
    this.isDemoMode = false,
  }) : _dioClient = dioClient,
       _demoStore = demoStore ?? DemoTripHistoryStore();

  final DioClient? _dioClient;
  final DemoTripHistoryStore _demoStore;
  final bool isDemoMode;

  static const String _reviewsEndpoint = '/api/v1/traveler/reviews';

  @override
  Future<TripReview> submitReview(TripReviewSubmission submission) async {
    if (isDemoMode) {
      return _demoStore.submitReview(submission);
    }

    final client = _dioClient;
    if (client == null) {
      throw const ServerFailure(
        TripHistoryStringsEn.productionReviewMutationDisabled,
      );
    }

    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        _reviewsEndpoint,
        data: {
          'tripId': submission.tripId,
          'bookingCode': submission.bookingCode,
          'travelerId': submission.travelerId,
          'rating': submission.rating,
          'title': submission.title,
          'content': submission.content,
          'photos': submission.photos.map((p) => p.name).toList(),
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ServerFailure(TripHistoryStringsEn.errorMessageGeneric);
      }

      return TripReview(
        id: data['id']?.toString() ?? '',
        tripId: submission.tripId,
        travelerId: submission.travelerId,
        rating: submission.rating,
        title: submission.title,
        content: submission.content,
        photoUrls:
            (data['photos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdAt:
            DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 404 || e.response == null)) {
        // Production notice: Backend PR #30 unmerged
        throw const ServerFailure(
          TripHistoryStringsEn.productionReviewMutationDisabled,
        );
      }
      throw ErrorMapper.toFailure(e);
    }
  }

  @override
  Future<TripReview> updateReview(TripReviewSubmission submission) async {
    if (isDemoMode) {
      return _demoStore.updateReview(submission);
    }

    final client = _dioClient;
    if (client == null) {
      throw const ServerFailure(
        TripHistoryStringsEn.productionReviewMutationDisabled,
      );
    }

    try {
      final response = await client.dio.put<Map<String, dynamic>>(
        '$_reviewsEndpoint/${submission.existingReviewId}',
        data: {
          'rating': submission.rating,
          'title': submission.title,
          'content': submission.content,
          'photos': submission.photos.map((p) => p.name).toList(),
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ServerFailure(TripHistoryStringsEn.errorMessageGeneric);
      }

      return TripReview(
        id: submission.existingReviewId ?? '',
        tripId: submission.tripId,
        travelerId: submission.travelerId,
        rating: submission.rating,
        title: submission.title,
        content: submission.content,
        photoUrls:
            (data['photos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 404 || e.response == null)) {
        throw const ServerFailure(
          TripHistoryStringsEn.productionReviewMutationDisabled,
        );
      }
      throw ErrorMapper.toFailure(e);
    }
  }

  @override
  Future<TripReview?> getReviewForTrip({
    required int travelerId,
    required String tripId,
  }) async {
    if (isDemoMode) {
      final trip = _demoStore.getTripById(
        travelerId: travelerId,
        tripId: tripId,
      );
      return trip?.review;
    }

    final client = _dioClient;
    if (client == null) return null;

    try {
      final response = await client.dio.get<Map<String, dynamic>>(
        '$_reviewsEndpoint/trip/$tripId',
      );
      final data = response.data;
      if (data == null) return null;

      return TripReview(
        id: data['id']?.toString() ?? '',
        tripId: tripId,
        travelerId: travelerId,
        rating: (data['rating'] as num?)?.toInt() ?? 5,
        title: data['title']?.toString() ?? '',
        content: data['content']?.toString() ?? '',
        photoUrls:
            (data['photos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdAt:
            DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
    } catch (e) {
      return null;
    }
  }
}
