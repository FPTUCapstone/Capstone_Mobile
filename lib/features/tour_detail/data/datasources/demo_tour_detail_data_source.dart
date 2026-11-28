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
      title: summary?.title ?? 'Khám phá Đà Nẵng 3N2Đ',
      description:
          'Khám phá Đà Nẵng, bán đảo Sơn Trà, Ngũ Hành Sơn và Hội An cùng nhà điều hành địa phương uy tín.',
      destinations: summary?.destinations.isNotEmpty == true
          ? summary!.destinations
          : const ['Đà Nẵng', 'Hội An', 'Sơn Trà'],
      durationDays: summary?.durationDays ?? 3,
      operatorName: summary?.operatorName ?? 'Central Vietnam Travel',
      operatorPhone: '1900 1808',
      operatorEmail: 'info@example.test',
      basePrice: summary?.basePrice ?? 2890000,
      currency: summary?.currency ?? 'VND',
      images: const [
        'assets/images/destinations/son_tra_pagoda.jpg',
        'assets/images/destinations/my_khe_beach.jpg',
        'assets/images/destinations/hoian_ancient_town.jpg',
      ],
      inclusions: const [
        'Xe du lịch đời mới có điều hòa',
        'Khách sạn 3 sao tiêu chuẩn',
        'Các bữa ăn và vé tham quan theo lịch trình',
        'Hướng dẫn viên du lịch giàu kinh nghiệm',
      ],
      exclusions: const [
        'Vé máy bay khứ hồi đến Đà Nẵng',
        'Chi phí cá nhân',
        'Tiền tip và các hoạt động tự túc',
      ],
      cancellationPolicy:
          'Miễn phí hủy trước ngày khởi hành ít nhất 7 ngày. Hủy từ 3–6 ngày trước khởi hành tính phí 50%. Hủy muộn hơn không hoàn tiền.',
      itineraryDays: const [
        TourItineraryDay(
          dayNumber: 1,
          title: 'Bán đảo Sơn Trà và Biển Mỹ Khê',
          description: 'Đón khách tại Đà Nẵng và khám phá cung đường biển.',
          activities: ['Đón sân bay', 'Chùa Linh Ứng', 'Biển Mỹ Khê'],
        ),
        TourItineraryDay(
          dayNumber: 2,
          title: 'Ngũ Hành Sơn và Phố cổ Hội An',
          description: 'Tham quan danh thắng văn hóa và Phố cổ Hội An.',
          activities: ['Ngũ Hành Sơn', 'Chùa Cầu', 'Phố cổ Hội An'],
        ),
        TourItineraryDay(
          dayNumber: 3,
          title: 'Chợ địa phương và tiễn sân bay',
          description: 'Mua sắm đặc sản địa phương trước khi ra sân bay.',
          activities: ['Chợ Hàn', 'Tiễn sân bay'],
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
          authorName: 'Nguyễn Minh Anh',
          rating: 5,
          comment: 'Tour tổ chức rất chu đáo với lịch trình hợp lý.',
          createdAtUtc: DateTime.utc(2026, 9, 20, 10),
        ),
      ],
      averageRating: 4.8,
      reviewCount: 24,
    );
  }
}
