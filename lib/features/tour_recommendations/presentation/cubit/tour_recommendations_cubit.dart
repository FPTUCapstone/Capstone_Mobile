import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendation.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_state.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// Cubit managing Tour Recommendations for UC-25.
///
/// Because the canonical Backend currently has no tour recommendation endpoint (`NO_BACKEND`),
/// production mode strictly exposes [TourRecommendationsStatus.pendingIntegration].
/// Demo mode is strictly isolated to debug review (`kDebugMode && ?demo=true`).
final class TourRecommendationsCubit extends Cubit<TourRecommendationsState> {
  TourRecommendationsCubit({this.isDemoMode = false})
    : super(TourRecommendationsState.initial(isDemoMode: isDemoMode));

  final bool isDemoMode;

  /// Loads initial recommendations.
  Future<void> load() async {
    emit(TourRecommendationsState.loading(isDemoMode: isDemoMode));

    if (!isDemoMode) {
      // Production truthfulness: No backend endpoint exists for tour recommendations.
      // Do not invent fake calls or simulate fake scores in production.
      emit(TourRecommendationsState.pendingIntegration(isDemoMode: isDemoMode));
      return;
    }

    // Demo Mode: Deterministic fixtures respecting canonical rules:
    // - BR-56: Demo fixtures represent Administrator-approved and publicly
    //   published Tours only (authoritative publication enforcement remains
    //   a Backend responsibility once the recommendation endpoint exists).
    // - similarity threshold > 80% (0.80)
    // - ordered descending by similarity score
    loadDemoPage(1);
  }

  /// Refreshes recommendations.
  Future<void> refresh() async {
    await load();
  }

  /// Loads a specific page in Demo Mode.
  void loadDemoPage(int page) {
    if (!isDemoMode) return;

    final allItems = _demoRecommendations;
    const pageSize = 3;
    final totalPages = (allItems.length / pageSize).ceil();
    final safePage = page.clamp(1, totalPages);
    final startIndex = (safePage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, allItems.length);
    final pageItems = allItems.sublist(startIndex, endIndex);

    emit(
      TourRecommendationsState.success(
        recommendations: pageItems,
        currentPage: safePage,
        totalPages: totalPages,
        totalItems: allItems.length,
        isDemoMode: true,
      ),
    );
  }

  /// Simulates MSG28 state in Demo Mode (no interest tags configured).
  void simulateNoPreferences() {
    if (!isDemoMode) return;
    emit(const TourRecommendationsState.noPreferences(isDemoMode: true));
  }

  /// Simulates MSG64 state in Demo Mode (no tours reach > 80% threshold).
  void simulateNoMatches() {
    if (!isDemoMode) return;
    emit(const TourRecommendationsState.noMatches(isDemoMode: true));
  }

  /// Simulates MSG127 state in Demo Mode (system/network failure).
  void simulateError() {
    if (!isDemoMode) return;
    emit(
      const TourRecommendationsState.error(
        TourRecommendationsState.msg127,
        isDemoMode: true,
      ),
    );
  }

  /// Deterministic fixtures for Demo Mode (strictly ordered descending by score, all > 80%).
  static final List<TourRecommendation> _demoRecommendations = [
    TourRecommendation(
      tour: TourSummary(
        tourId: 'rec-101',
        title: 'Khám phá Đà Nẵng – Bán đảo Sơn Trà – Ngũ Hành Sơn 3N2Đ',
        destinations: const ['Đà Nẵng', 'Hội An'],
        operatorName: 'Saigontourist Miền Trung',
        durationDays: 3,
        basePrice: 2890000,
        currency: 'VND',
        representativeScheduleId: 'sch-101',
        departureAtUtc: DateTime.utc(2026, 10, 15, 2, 0),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 8,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b',
      ),
      matchingScore: 0.95,
      matchReasons: const [
        'Phù hợp 95% với sở thích Văn hoá & Di sản',
        'Thời lượng 3 ngày khớp kế hoạch du lịch',
      ],
    ),
    TourRecommendation(
      tour: TourSummary(
        tourId: 'rec-102',
        title:
            'Tour Hội An Phố Cổ – Rừng Dừa Bảy Mẫu – Thưởng thức Ẩm thực 2N1Đ',
        destinations: const ['Hội An'],
        operatorName: 'Hội An Eco Travel',
        durationDays: 2,
        basePrice: 1650000,
        currency: 'VND',
        representativeScheduleId: 'sch-102',
        departureAtUtc: DateTime.utc(2026, 10, 18, 1, 30),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 5,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1528127269322-539801943592',
      ),
      matchingScore: 0.91,
      matchReasons: const [
        'Khớp sở thích Ẩm thực truyền thống',
        'Khởi hành vào cuối tuần thuận tiện',
      ],
    ),
    TourRecommendation(
      tour: TourSummary(
        tourId: 'rec-103',
        title: 'Trải nghiệm Bà Nà Hills Cầu Vàng – Làng Pháp Đẳng Cấp 1 Ngày',
        destinations: const ['Đà Nẵng', 'Bà Nà'],
        operatorName: 'Danang Green Travel',
        durationDays: 1,
        basePrice: 1250000,
        currency: 'VND',
        representativeScheduleId: 'sch-103',
        departureAtUtc: DateTime.utc(2026, 10, 20, 1, 0),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 12,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1583417319070-4a69db38a482',
      ),
      matchingScore: 0.88,
      matchReasons: const ['Địa điểm nổi bật phù hợp phong cách khám phá'],
    ),
    TourRecommendation(
      tour: TourSummary(
        tourId: 'rec-104',
        title: 'Tour Cù Lao Chàm Lặn Ngắm San Hô – Thưởng thức Hải Sản Biển',
        destinations: const ['Hội An', 'Cù Lao Chàm'],
        operatorName: 'Cham Island Discovery',
        durationDays: 1,
        basePrice: 950000,
        currency: 'VND',
        representativeScheduleId: 'sch-104',
        departureAtUtc: DateTime.utc(2026, 10, 22, 1, 0),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 4,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
      ),
      matchingScore: 0.84,
      matchReasons: const ['Phù hợp sở thích Thiên nhiên & Biển đảo'],
    ),
    TourRecommendation(
      tour: TourSummary(
        tourId: 'rec-105',
        title: 'Tour Cố Đô Huế – Đại Nội Hoàng Thành – Lăng Khải Định 1 Ngày',
        destinations: const ['Huế'],
        operatorName: 'Cố Đô Heritage Travel',
        durationDays: 1,
        basePrice: 850000,
        currency: 'VND',
        representativeScheduleId: 'sch-105',
        departureAtUtc: DateTime.utc(2026, 10, 25, 0, 30),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 6,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1569154941061-e231b4725ef1',
      ),
      matchingScore: 0.82,
      matchReasons: const ['Phù hợp sở thích Lịch sử & Văn hoá'],
    ),
  ];
}
