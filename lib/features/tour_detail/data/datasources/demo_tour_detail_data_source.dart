import 'package:trip_mate_mobile/features/tour_detail/data/datasources/tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_day.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_review_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// Deterministic debug-only UC-26 fixtures selected by the composition root.
final class DemoTourDetailDataSource implements TourDetailDataSource {
  const DemoTourDetailDataSource();

  static const knownTourIds = {
    'demo-tour-1',
    'tour-123',
    'rec-101',
    'rec-102',
    'rec-103',
    'rec-104',
    'rec-105',
  };

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) async {
    if (!knownTourIds.contains(tourId)) return null;
    final summary = initialSummary?.tourId == tourId ? initialSummary : null;
    return TourDetail(
      tourId: tourId,
      title: summary?.title ?? 'Da Nang Discovery 3D2N',
      description:
          'Explore Da Nang, Son Tra Peninsula, Marble Mountains, and Hoi An with a published local tour operator.',
      destinations: summary?.destinations.isNotEmpty == true
          ? summary!.destinations
          : const ['Da Nang', 'Hoi An', 'Son Tra'],
      durationDays: summary?.durationDays ?? 3,
      operatorName: summary?.operatorName ?? 'Central Vietnam Travel',
      operatorPhone: '1900 1808',
      operatorEmail: 'info@example.test',
      basePrice: summary?.basePrice ?? 2890000,
      currency: summary?.currency ?? 'VND',
      images: const [
        'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b',
        'https://images.unsplash.com/photo-1528127269322-539801943592',
      ],
      inclusions: const [
        'Air-conditioned transportation',
        'Three-star hotel accommodation',
        'Meals and attraction tickets listed in the itinerary',
        'English-speaking tour guide',
      ],
      exclusions: const [
        'Flights to and from Da Nang',
        'Personal expenses',
        'Tips and optional activities',
      ],
      cancellationPolicy:
          'Free cancellation at least 7 days before departure. A 50% fee applies 3–6 days before departure. Later cancellations are non-refundable.',
      itineraryDays: const [
        TourItineraryDay(
          dayNumber: 1,
          title: 'Son Tra Peninsula and My Khe Beach',
          description: 'Arrive in Da Nang and explore the coast.',
          activities: ['Airport pickup', 'Linh Ung Pagoda', 'My Khe Beach'],
        ),
        TourItineraryDay(
          dayNumber: 2,
          title: 'Marble Mountains and Hoi An',
          description: 'Visit cultural landmarks and Hoi An Ancient Town.',
          activities: ['Marble Mountains', 'Japanese Bridge', 'Hoi An'],
        ),
        TourItineraryDay(
          dayNumber: 3,
          title: 'Local market and departure',
          description: 'Visit a local market before airport transfer.',
          activities: ['Han Market', 'Airport transfer'],
        ),
      ],
      schedules: [
        TourScheduleItem(
          scheduleId: 'sch-001',
          departureAtUtc: DateTime.utc(2026, 10, 15, 2),
          price: 2890000,
          currency: 'VND',
          remainingSlots: 8,
          totalSlots: 20,
          availabilityStatus: AvailabilityStatus.available,
        ),
        TourScheduleItem(
          scheduleId: 'sch-003',
          departureAtUtc: DateTime.utc(2026, 10, 29, 2),
          price: 3090000,
          currency: 'VND',
          remainingSlots: 0,
          totalSlots: 20,
          availabilityStatus: AvailabilityStatus.soldOut,
        ),
      ],
      reviews: [
        TourReviewItem(
          reviewId: 'rev-01',
          authorName: 'Alex Nguyen',
          rating: 5,
          comment: 'A well-organized tour with a thoughtful itinerary.',
          createdAtUtc: DateTime.utc(2026, 9, 20, 10),
        ),
      ],
      averageRating: 4.8,
      reviewCount: 24,
    );
  }
}
