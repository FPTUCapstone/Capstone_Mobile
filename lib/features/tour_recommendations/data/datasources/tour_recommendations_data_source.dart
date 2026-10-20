import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

abstract interface class TourRecommendationsDataSource {
  Future<TourRecommendationCandidates> fetchCandidates();
}

sealed class TourRecommendationCandidates {
  const TourRecommendationCandidates();
}

final class TourRecommendationCandidatesAvailable
    extends TourRecommendationCandidates {
  const TourRecommendationCandidatesAvailable(this.items);
  final List<TourRecommendationCandidate> items;
}

final class TourRecommendationCandidatesPending
    extends TourRecommendationCandidates {
  const TourRecommendationCandidatesPending();
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
  Future<TourRecommendationCandidates> fetchCandidates() async =>
      const TourRecommendationCandidatesPending();
}

final class DemoTourRecommendationsDataSource
    implements TourRecommendationsDataSource {
  const DemoTourRecommendationsDataSource();

  @override
  Future<TourRecommendationCandidates> fetchCandidates() async =>
      TourRecommendationCandidatesAvailable(_fixtures);

  static final List<TourRecommendationCandidate> _fixtures = [
    _candidate(
      id: 'rec-101',
      title: 'Da Nang, Son Tra Peninsula and Marble Mountains — 3D2N',
      destinations: const ['Da Nang', 'Hoi An'],
      operatorName: 'Central Vietnam Travel',
      durationDays: 3,
      price: 2890000,
      score: 0.95,
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
      score: 0.91,
      reasons: const ['Matches your local cuisine interests'],
    ),
    _candidate(
      id: 'rec-103',
      title: 'Ba Na Hills, Golden Bridge and French Village — Day Tour',
      destinations: const ['Da Nang', 'Ba Na'],
      operatorName: 'Danang Green Travel',
      durationDays: 1,
      price: 1250000,
      score: 0.88,
      reasons: const ['Popular landmarks match your exploration style'],
    ),
    _candidate(
      id: 'rec-104',
      title: 'Cham Islands Snorkeling and Seafood — Day Tour',
      destinations: const ['Hoi An', 'Cham Islands'],
      operatorName: 'Cham Island Discovery',
      durationDays: 1,
      price: 950000,
      score: 0.84,
      reasons: const ['Matches your nature and island interests'],
    ),
    _candidate(
      id: 'rec-105',
      title: 'Hue Imperial City and Khai Dinh Tomb — Day Tour',
      destinations: const ['Hue'],
      operatorName: 'Heritage Travel',
      durationDays: 1,
      price: 850000,
      score: 0.82,
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
