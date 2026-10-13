import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_refund_info.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

/// In-memory deterministic store for demo mode & acceptance test fixtures.
class DemoTripHistoryStore {
  DemoTripHistoryStore({DateTime? now})
    : _referenceTime = now ?? DateTime.now() {
    reset();
  }

  /// Explicit Demo traveler identity. Exists ONLY inside explicit Demo architecture.
  /// This must NOT be confused with or used as Production authenticated identity.
  static const int demoTravelerId = 1;

  final DateTime _referenceTime;
  final List<TripHistoryItem> _items = [];

  DateTime get now => _referenceTime;

  void reset() {
    _items
      ..clear()
      ..addAll(_buildDefaultFixtures());
  }

  List<TripHistoryItem> _buildDefaultFixtures() {
    final now = _referenceTime;

    return [
      // 1. Upcoming Tour
      TripHistoryItem(
        id: 'trip-tour-001',
        bookingCode: 'BK-TOUR-001',
        title: 'Ba Na Hills & Golden Bridge Discovery',
        type: TripType.tour,
        status: TripStatus.upcoming,
        departureDate: now.add(const Duration(days: 12)),
        participantsCount: 2,
        totalAmount: 2400000,
        travelerId: demoTravelerId,
        hasEticket: true,
        providerName: 'Da Nang Green Travel',
        location: 'Ba Na Hills, Da Nang',
      ),

      // 2. Upcoming Commercial Service
      TripHistoryItem(
        id: 'trip-srv-002',
        bookingCode: 'BK-SRV-002',
        title: 'Novotel Danang Premier Han River - Deluxe Room',
        type: TripType.commercialService,
        status: TripStatus.upcoming,
        departureDate: now.add(const Duration(days: 17)),
        participantsCount: 2,
        totalAmount: 3200000,
        travelerId: demoTravelerId,
        hasEticket: true,
        providerName: 'Novotel Danang Premier',
        location: 'Hai Chau, Da Nang',
      ),

      // 3. Completed Tour - Unreviewed (Eligible for Write Review)
      TripHistoryItem(
        id: 'trip-tour-003',
        bookingCode: 'BK-TOUR-003',
        title: 'Hoi An Ancient Town Evening Lantern Tour',
        type: TripType.tour,
        status: TripStatus.completed,
        departureDate: now.subtract(const Duration(days: 7)),
        participantsCount: 2,
        totalAmount: 1800000,
        travelerId: demoTravelerId,
        hasEticket: true,
        review: null,
        providerName: 'Hoi An Heritage Tours',
        location: 'Hoi An, Quang Nam',
      ),

      // 4. Completed Tour - Reviewed 2 days ago (Within 7-day edit window)
      TripHistoryItem(
        id: 'trip-tour-004',
        bookingCode: 'BK-TOUR-004',
        title: 'My Son Sanctuary Sunrise Tour',
        type: TripType.tour,
        status: TripStatus.completed,
        departureDate: now.subtract(const Duration(days: 10)),
        participantsCount: 1,
        totalAmount: 950000,
        travelerId: demoTravelerId,
        hasEticket: true,
        review: TripReview(
          id: 'rev-004',
          tripId: 'trip-tour-004',
          travelerId: demoTravelerId,
          rating: 5,
          title: 'Amazing Sunrise & Rich Heritage',
          content:
              'The guide was extremely knowledgeable and the sunrise view was unforgettable.',
          photoUrls: const ['https://example.com/photos/myson1.jpg'],
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        providerName: 'My Son Heritage Travel',
        location: 'Duy Xuyen, Quang Nam',
      ),

      // 5. Completed Commercial Service - Reviewed 18 days ago (Read-only review, > 7 days)
      TripHistoryItem(
        id: 'trip-srv-005',
        bookingCode: 'BK-SRV-005',
        title: 'Madame Lan Restaurant Authentic Vietnamese Dining',
        type: TripType.commercialService,
        status: TripStatus.completed,
        departureDate: now.subtract(const Duration(days: 25)),
        participantsCount: 4,
        totalAmount: 1200000,
        travelerId: demoTravelerId,
        hasEticket: true,
        review: TripReview(
          id: 'rev-005',
          tripId: 'trip-srv-005',
          travelerId: demoTravelerId,
          rating: 4,
          title: 'Delicious food and pleasant atmosphere',
          content:
              'Great food quality and fast service. Highly recommend the pancake and spring rolls.',
          photoUrls: const [],
          createdAt: now.subtract(const Duration(days: 18)),
        ),
        providerName: 'Madame Lan Restaurant',
        location: 'Hai Chau, Da Nang',
      ),

      // 6. Completed Self-Planned Itinerary (Not a booking; reviews not applicable)
      TripHistoryItem(
        id: 'trip-itin-006',
        bookingCode: 'ITIN-2026-006',
        title: 'Da Nang 3-Day Coastal & Food Exploration',
        type: TripType.itinerary,
        status: TripStatus.completed,
        departureDate: now.subtract(const Duration(days: 35)),
        participantsCount: 2,
        totalAmount: 0,
        travelerId: demoTravelerId,
        hasEticket: false,
        itineraryId: 1,
        location: 'Da Nang City',
      ),

      // 7. Cancelled Tour - Refunded
      TripHistoryItem(
        id: 'trip-tour-007',
        bookingCode: 'BK-TOUR-007',
        title: 'Hue Imperial Citadel Full-Day Heritage Tour',
        type: TripType.tour,
        status: TripStatus.cancelled,
        departureDate: now.subtract(const Duration(days: 15)),
        participantsCount: 2,
        totalAmount: 2000000,
        travelerId: demoTravelerId,
        refundInfo: const TripRefundInfo(
          status: RefundStatus.refunded,
          amount: 2000000,
          channel: 'VNPay (Txn #VN789012)',
          note: 'Full refund successfully processed within 24 hours.',
        ),
        providerName: 'Central Vietnam Travel',
        location: 'Hue City',
      ),

      // 8. Cancelled Commercial Service - Refund Processing
      TripHistoryItem(
        id: 'trip-srv-008',
        bookingCode: 'BK-SRV-008',
        title: 'Hai Van Pass Motorbike Rental Service',
        type: TripType.commercialService,
        status: TripStatus.cancelled,
        departureDate: now.subtract(const Duration(days: 8)),
        participantsCount: 1,
        totalAmount: 500000,
        travelerId: demoTravelerId,
        refundInfo: const TripRefundInfo(
          status: RefundStatus.processing,
          amount: 500000,
          channel: 'Bank Transfer (Techcombank)',
          note: 'Refund request accepted; bank processing underway.',
        ),
        providerName: 'Hai Van Rentals',
        location: 'Da Nang',
      ),

      // 9. Cancelled Tour - Non-Refundable
      TripHistoryItem(
        id: 'trip-tour-009',
        bookingCode: 'BK-TOUR-009',
        title: 'Cu Lao Cham Island Coral Reef Snorkeling Tour',
        type: TripType.tour,
        status: TripStatus.cancelled,
        departureDate: now.subtract(const Duration(days: 4)),
        participantsCount: 2,
        totalAmount: 1600000,
        travelerId: demoTravelerId,
        refundInfo: const TripRefundInfo(
          status: RefundStatus.nonRefundable,
          amount: 0,
          channel: 'N/A',
          note: 'Non-refundable due to same-day traveler cancellation.',
        ),
        providerName: 'Cham Island Expeditions',
        location: 'Hoi An, Quang Nam',
      ),

      // 10. Foreign Traveler Trip - Must be isolated (BR-90)
      TripHistoryItem(
        id: 'trip-tour-999',
        bookingCode: 'BK-TOUR-999',
        title: 'Ha Long Bay 2-Day Luxury Cruise',
        type: TripType.tour,
        status: TripStatus.upcoming,
        departureDate: now.add(const Duration(days: 30)),
        participantsCount: 2,
        totalAmount: 5800000,
        travelerId: 999, // Foreign traveler!
        hasEticket: true,
        providerName: 'Ha Long Luxury Cruises',
        location: 'Quang Ninh',
      ),
    ];
  }

  /// BR-90: Strictly returns only the records belonging to [travelerId] in Demo mode.
  /// CR-01: Paginated.
  /// Default sorting: departureDate descending.
  TripHistoryPageResult getTrips({
    int? travelerId,
    TripStatus? status,
    TripType? type,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) {
    final effectiveTravelerId = travelerId ?? demoTravelerId;
    var filtered = _items
        .where((item) => item.travelerId == effectiveTravelerId)
        .toList(growable: false);

    if (status != null) {
      filtered = filtered
          .where((item) => item.status == status)
          .toList(growable: false);
    }

    if (type != null) {
      filtered = filtered
          .where((item) => item.type == type)
          .toList(growable: false);
    }

    if (startDate != null) {
      filtered = filtered
          .where(
            (item) =>
                item.departureDate.isAfter(startDate) ||
                item.departureDate.isAtSameMomentAs(startDate),
          )
          .toList(growable: false);
    }

    if (endDate != null) {
      filtered = filtered
          .where(
            (item) =>
                item.departureDate.isBefore(endDate) ||
                item.departureDate.isAtSameMomentAs(endDate),
          )
          .toList(growable: false);
    }

    // Default sorting: departure date in descending order
    final sorted = [...filtered]
      ..sort((a, b) => b.departureDate.compareTo(a.departureDate));

    final totalCount = sorted.length;
    final startIndex = ((page - 1) * pageSize).clamp(0, totalCount);
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);
    final pageItems = sorted.sublist(startIndex, endIndex);

    return TripHistoryPageResult(
      items: pageItems,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  TripHistoryItem? getTripById({int? travelerId, required String tripId}) {
    final effectiveTravelerId = travelerId ?? demoTravelerId;
    final match = _items.where(
      (item) => item.id == tripId && item.travelerId == effectiveTravelerId,
    );
    return match.isEmpty ? null : match.first;
  }

  TripReview submitReview(TripReviewSubmission submission) {
    final effectiveTravelerId = submission.travelerId ?? demoTravelerId;
    final tripIndex = _items.indexWhere(
      (item) =>
          item.id == submission.tripId &&
          item.travelerId == effectiveTravelerId,
    );

    if (tripIndex == -1) {
      throw const PermissionFailure(TripHistoryStringsEn.permissionDenied);
    }

    final item = _items[tripIndex];

    // BR-91: Trip must be completed
    if (item.status != TripStatus.completed) {
      throw const ValidationFailure(
        TripHistoryStringsEn.noticeReviewNotCompleted,
      );
    }

    // BR-92: At most one review per booking
    if (item.review != null && !submission.isEdit) {
      throw const ConflictFailure(
        TripHistoryStringsEn.noticeReviewAlreadyExists,
      );
    }

    // BR-93: Rating is mandatory integer between 1 and 5
    if (submission.rating < 1 || submission.rating > 5) {
      throw const ValidationFailure(
        TripHistoryStringsEn.validationRatingRequired,
      );
    }

    // BR-94: Content policy screening (Demo simulation)
    _screenContentPolicy(submission.title, submission.content);

    // Photos validation (type & size)
    for (final photo in submission.photos) {
      if (!photo.isValidType) {
        throw const ValidationFailure(
          TripHistoryStringsEn.validationPhotoInvalidType,
        );
      }
      if (!photo.isValidSize) {
        throw const ValidationFailure(
          TripHistoryStringsEn.validationPhotoExceedsLimit,
        );
      }
    }

    final review = TripReview(
      id:
          submission.existingReviewId ??
          'rev-${DateTime.now().millisecondsSinceEpoch}',
      tripId: item.id,
      travelerId: effectiveTravelerId,
      rating: submission.rating,
      title: submission.title.trim(),
      content: submission.content.trim(),
      photoUrls: submission.photos.map((p) => p.name).toList(),
      createdAt: item.review?.createdAt ?? DateTime.now(),
      updatedAt: submission.isEdit ? DateTime.now() : null,
    );

    // Update item with published review
    _items[tripIndex] = TripHistoryItem(
      id: item.id,
      bookingCode: item.bookingCode,
      title: item.title,
      type: item.type,
      status: item.status,
      departureDate: item.departureDate,
      participantsCount: item.participantsCount,
      totalAmount: item.totalAmount,
      travelerId: item.travelerId,
      hasEticket: item.hasEticket,
      review: review,
      refundInfo: item.refundInfo,
      itineraryId: item.itineraryId,
      providerName: item.providerName,
      location: item.location,
    );

    return review;
  }

  TripReview updateReview(TripReviewSubmission submission) {
    final effectiveTravelerId = submission.travelerId ?? demoTravelerId;
    final tripIndex = _items.indexWhere(
      (item) =>
          item.id == submission.tripId &&
          item.travelerId == effectiveTravelerId,
    );

    if (tripIndex == -1) {
      throw const PermissionFailure(TripHistoryStringsEn.permissionDenied);
    }

    final item = _items[tripIndex];
    final existingReview = item.review;

    if (existingReview == null) {
      throw const NotFoundFailure('Review not found.');
    }

    // BR-95: Edit window within 7 days
    if (!existingReview.isEditable(_referenceTime)) {
      throw const ValidationFailure(TripHistoryStringsEn.reviewReadOnlyNotice);
    }

    return submitReview(submission);
  }

  void _screenContentPolicy(String title, String content) {
    final forbiddenKeywords = ['violation', 'profanity', 'offensive', 'spam'];
    final lowerTitle = title.toLowerCase();
    final lowerContent = content.toLowerCase();

    for (final kw in forbiddenKeywords) {
      if (lowerTitle.contains(kw) || lowerContent.contains(kw)) {
        throw const ValidationFailure(
          TripHistoryStringsEn.validationContentPolicyViolation,
        );
      }
    }
  }
}
