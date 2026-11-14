import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_query.dart';
import 'package:trip_mate_mobile/features/tour_search/data/models/tour_search_page_model.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

abstract interface class TourRecommendationsDataSource {
  Future<TourRecommendationCandidates> fetchCandidates(
    TourRecommendationsQuery query,
  );
}

sealed class TourRecommendationCandidates {
  const TourRecommendationCandidates();
}

final class TourRecommendationCandidatesAvailable
    extends TourRecommendationCandidates {
  const TourRecommendationCandidatesAvailable(
    this.items, {
    this.page = 1,
    this.totalPages = 1,
    this.serverPaged = false,
    int? totalItems,
  }) : totalItems = totalItems ?? items.length;
  final List<TourRecommendationCandidate> items;
  final int page;
  final int totalPages;
  final int totalItems;
  final bool serverPaged;
}

final class TourRecommendationCandidatesPending
    extends TourRecommendationCandidates {
  const TourRecommendationCandidatesPending();
}

final class TourRecommendationCandidatesNoPreferences
    extends TourRecommendationCandidates {
  const TourRecommendationCandidatesNoPreferences();
}

final class TourRecommendationCandidate {
  const TourRecommendationCandidate({
    required this.tour,
    required this.matchingScore,
    required this.isApproved,
    required this.isPublic,
    this.matchReasons = const [],
  });

  final TourSummary tour;
  final double matchingScore;
  final bool isApproved;
  final bool isPublic;
  final List<String> matchReasons;
}

final class PendingTourRecommendationsDataSource
    implements TourRecommendationsDataSource {
  const PendingTourRecommendationsDataSource();

  @override
  Future<TourRecommendationCandidates> fetchCandidates(
    TourRecommendationsQuery query,
  ) async => const TourRecommendationCandidatesPending();
}

final class DioTourRecommendationsDataSource
    implements TourRecommendationsDataSource {
  DioTourRecommendationsDataSource(DioClient client) : _dio = client.dio;

  final Dio _dio;
  Future<TourRecommendationCandidates>? _initialRefresh;

  @override
  Future<TourRecommendationCandidates> fetchCandidates(
    TourRecommendationsQuery query,
  ) async {
    if (query.refresh) return _refreshOnce(query);
    final latest = await _request(query, refresh: false);
    if (latest is! _RecommendationPage ||
        latest.hasSnapshot ||
        query.page != 1) {
      return latest;
    }
    return _initialRefresh ??= _request(
      query,
      refresh: true,
    ).whenComplete(() => _initialRefresh = null);
  }

  Future<TourRecommendationCandidates> _refreshOnce(
    TourRecommendationsQuery query,
  ) => _initialRefresh ??= _request(
    query,
    refresh: true,
  ).whenComplete(() => _initialRefresh = null);

  Future<TourRecommendationCandidates> _request(
    TourRecommendationsQuery query, {
    required bool refresh,
  }) async {
    try {
      final response = refresh
          ? await _dio.post<Object?>(
              '/api/v1/tour-recommendations/refresh',
              data: {
                'destination': query.destination,
                'startDate': _date(query.startDate),
                'endDate': _date(query.endDate),
                'minBudget': query.minBudget,
                'maxBudget': query.maxBudget,
              },
            )
          : await _dio.get<Object?>(
              '/api/v1/tour-recommendations',
              queryParameters: {'page': query.page},
            );
      return _parsePage(_jsonObject(response.data));
    } on DioException catch (error) {
      final data = error.response?.data;
      final problem = data is Map
          ? Map<String, Object?>.from(data)
          : const <String, Object?>{};
      if (error.response?.statusCode == 422 &&
          problem['errorCode'] ==
              'tour_recommendation.interest_tags_required') {
        return const TourRecommendationCandidatesNoPreferences();
      }
      rethrow;
    }
  }

  _RecommendationPage _parsePage(Map<String, Object?> json) {
    final rawItems = json['items'];
    if (rawItems is! List<Object?> ||
        json['criteria'] != null && json['criteria'] is! Map) {
      throw const FormatException('Invalid tour recommendations response.');
    }
    final items = rawItems
        .map((raw) {
          final item = _jsonObject(raw);
          final reasons = item['matchingReasons'];
          final score = item['matchingScore'];
          if (reasons is! List<Object?> ||
              reasons.any((value) => value is! String) ||
              score is! num ||
              score <= 80 ||
              score > 100) {
            throw const FormatException('Invalid recommendation item.');
          }
          final tour = TourSearchItemModel.fromJson(
            _jsonObject(item['tour']),
          ).toEntity();
          if (tour.availabilityStatus != AvailabilityStatus.available ||
              tour.representativeScheduleId == null ||
              (tour.remainingSlots ?? 0) <= 0) {
            throw const FormatException('Unavailable recommendation item.');
          }
          return TourRecommendationCandidate(
            tour: tour,
            matchingScore: score.toDouble(),
            isApproved: true,
            isPublic: true,
            matchReasons: reasons.cast<String>(),
          );
        })
        .toList(growable: false);
    return _RecommendationPage(
      items,
      page: _requiredInt(json, 'page'),
      totalPages: _requiredInt(json, 'totalPages'),
      totalItems: _requiredInt(json, 'totalCount'),
      hasSnapshot: json['criteria'] != null,
    );
  }

  static String? _date(DateTime? value) =>
      value?.toIso8601String().split('T').first;
  static Map<String, Object?> _jsonObject(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return Map<String, Object?>.from(value);
    throw const FormatException('Expected a JSON object.');
  }

  static int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw FormatException('Invalid $key.');
  }
}

final class _RecommendationPage extends TourRecommendationCandidatesAvailable {
  const _RecommendationPage(
    super.items, {
    required super.page,
    required super.totalPages,
    required int totalItems,
    required this.hasSnapshot,
  }) : super(totalItems: totalItems, serverPaged: true);
  final bool hasSnapshot;
}

final class DemoTourRecommendationsDataSource
    implements TourRecommendationsDataSource {
  const DemoTourRecommendationsDataSource();

  @override
  Future<TourRecommendationCandidates> fetchCandidates(
    TourRecommendationsQuery query,
  ) async => TourRecommendationCandidatesAvailable(_fixtures);

  static final List<TourRecommendationCandidate> _fixtures = [
    _candidate(
      id: 'rec-101',
      title: 'Da Nang, Son Tra Peninsula and Marble Mountains — 3D2N',
      destinations: const ['Da Nang', 'Hoi An'],
      operatorName: 'Central Vietnam Travel',
      durationDays: 3,
      price: 2890000,
      score: 95,
      reasons: const [
        'Matches your culture and heritage interests',
        'The three-day duration fits your travel plan',
      ],
    ),
    _candidate(
      id: 'rec-102',
      title: 'Hoi An Ancient Town and Bay Mau Coconut Forest — 2D1N',
      destinations: const ['Hoi An'],
      operatorName: 'Hoi An Eco Travel',
      durationDays: 2,
      price: 1650000,
      score: 91,
      reasons: const ['Matches your local cuisine interests'],
    ),
    _candidate(
      id: 'rec-103',
      title: 'Ba Na Hills, Golden Bridge and French Village — Day Tour',
      destinations: const ['Da Nang', 'Ba Na'],
      operatorName: 'Danang Green Travel',
      durationDays: 1,
      price: 1250000,
      score: 88,
      reasons: const ['Popular landmarks match your exploration style'],
    ),
    _candidate(
      id: 'rec-104',
      title: 'Cham Islands Snorkeling and Seafood — Day Tour',
      destinations: const ['Hoi An', 'Cham Islands'],
      operatorName: 'Cham Island Discovery',
      durationDays: 1,
      price: 950000,
      score: 84,
      reasons: const ['Matches your nature and island interests'],
    ),
    _candidate(
      id: 'rec-105',
      title: 'Hue Imperial City and Khai Dinh Tomb — Day Tour',
      destinations: const ['Hue'],
      operatorName: 'Heritage Travel',
      durationDays: 1,
      price: 850000,
      score: 82,
      reasons: const ['Matches your history and culture interests'],
    ),
  ];

  static TourRecommendationCandidate _candidate({
    required String id,
    required String title,
    required List<String> destinations,
    required String operatorName,
    required int durationDays,
    required int price,
    required double score,
    required List<String> reasons,
  }) => TourRecommendationCandidate(
    tour: TourSummary(
      tourId: id,
      title: title,
      destinations: destinations,
      operatorName: operatorName,
      durationDays: durationDays,
      basePrice: price,
      currency: 'VND',
      representativeScheduleId: 'schedule-$id',
      departureAtUtc: DateTime.utc(2026, 10, 15),
      availabilityStatus: AvailabilityStatus.available,
      remainingSlots: 8,
      thumbnailUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b',
    ),
    matchingScore: score,
    isApproved: true,
    isPublic: true,
    matchReasons: reasons,
  );
}
