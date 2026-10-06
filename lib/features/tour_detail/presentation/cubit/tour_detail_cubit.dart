import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_day.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_review_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_state.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// Cubit managing Tour Details for UC-26.
///
/// Because the canonical Backend currently has no tour detail endpoint (`NO_BACKEND`),
/// production mode strictly exposes [TourDetailStatus.pendingIntegration] and renders
/// only the [TourSummary] supplied from the canonical UC-24 search path when available.
///
/// Business-rule notes:
/// - **BR-56** (*Only Administrator-approved and publicly published Tours may be
///   displayed to Traveler or Guest*): Production relies on UC-24 Backend search
///   for discoverable summary data, while full detail publication validation
///   remains Backend responsibility once `GET /api/v1/tours/{id}` exists.
///   Demo fixtures (`kDebugMode && ?demo=true`) represent Approved/Public Tours only.
/// - **MSG65**: Canonical UC-26 includes MSG65 when a Tour is no longer
///   existing/public, when all departure schedules are sold out or expired, or
///   when availability changes before Book Now. In Demo mode, [simulateSoldOut]
///   models the all-schedules-unavailable state, and [selectSchedule] surfaces
///   MSG65 if a sold-out schedule is selected.
final class TourDetailCubit extends Cubit<TourDetailState> {
  TourDetailCubit({TourSummary? initialSummary, this.isDemoMode = false})
    : super(
        TourDetailState.initial(
          initialSummary: initialSummary,
          isDemoMode: isDemoMode,
        ),
      );

  final bool isDemoMode;

  /// Loads tour details by [tourId].
  Future<void> load(String tourId) async {
    emit(
      TourDetailState.loading(
        initialSummary: state.initialSummary,
        isDemoMode: isDemoMode,
      ),
    );

    if (!isDemoMode) {
      // Production truthfulness: No backend endpoint exists for tour details.
      // Do not invent fake calls or simulate fake data in production.
      emit(
        TourDetailState.pendingIntegration(
          initialSummary: state.initialSummary,
          isDemoMode: isDemoMode,
        ),
      );
      return;
    }

    // Demo Mode: Deterministic fixture matching the requested tour or default fixture.
    final detail = _getDemoDetail(tourId, state.initialSummary);
    final firstAvailableSchedule = detail.schedules
        .where((s) => !s.isSoldOut)
        .firstOrNull;

    emit(
      TourDetailState.success(
        tourDetail: detail,
        initialSummary: state.initialSummary,
        selectedScheduleId:
            firstAvailableSchedule?.scheduleId ??
            detail.schedules.firstOrNull?.scheduleId,
        isDemoMode: true,
      ),
    );
  }

  /// Selects a departure schedule.
  /// Surfaces [TourDetailState.msg65] warning when a sold-out schedule is chosen.
  void selectSchedule(String scheduleId) {
    final detail = state.tourDetail;
    if (detail == null) return;

    final schedule = detail.schedules.cast<TourScheduleItem?>().firstWhere(
      (s) => s?.scheduleId == scheduleId,
      orElse: () => null,
    );

    if (schedule == null) return;

    if (schedule.isSoldOut) {
      emit(
        state.copyWith(
          selectedScheduleId: scheduleId,
          scheduleError: TourDetailState.msg65,
        ),
      );
    } else {
      emit(
        state.copyWith(
          selectedScheduleId: scheduleId,
          clearScheduleError: true,
        ),
      );
    }
  }

  /// Simulates a tour without reviews (tests MSG128 in Demo Mode).
  void simulateNoReviews() {
    if (!isDemoMode || state.tourDetail == null) return;
    final current = state.tourDetail!;
    final modified = TourDetail(
      tourId: current.tourId,
      title: current.title,
      description: current.description,
      destinations: current.destinations,
      durationDays: current.durationDays,
      operatorName: current.operatorName,
      operatorPhone: current.operatorPhone,
      operatorEmail: current.operatorEmail,
      basePrice: current.basePrice,
      currency: current.currency,
      images: current.images,
      inclusions: current.inclusions,
      exclusions: current.exclusions,
      cancellationPolicy: current.cancellationPolicy,
      itineraryDays: current.itineraryDays,
      schedules: current.schedules,
      reviews: const [],
      averageRating: null,
      reviewCount: 0,
    );
    emit(state.copyWith(tourDetail: modified));
  }

  /// Simulates the canonical all-schedules-unavailable state where all departure
  /// schedules are sold out (tests MSG65 in Demo Mode).
  void simulateSoldOut() {
    if (!isDemoMode || state.tourDetail == null) return;
    final current = state.tourDetail!;
    final modifiedSchedules = current.schedules
        .map(
          (s) => TourScheduleItem(
            scheduleId: s.scheduleId,
            departureAtUtc: s.departureAtUtc,
            price: s.price,
            currency: s.currency,
            remainingSlots: 0,
            totalSlots: s.totalSlots,
            availabilityStatus: AvailabilityStatus.soldOut,
          ),
        )
        .toList();

    final modified = TourDetail(
      tourId: current.tourId,
      title: current.title,
      description: current.description,
      destinations: current.destinations,
      durationDays: current.durationDays,
      operatorName: current.operatorName,
      operatorPhone: current.operatorPhone,
      operatorEmail: current.operatorEmail,
      basePrice: current.basePrice,
      currency: current.currency,
      images: current.images,
      inclusions: current.inclusions,
      exclusions: current.exclusions,
      cancellationPolicy: current.cancellationPolicy,
      itineraryDays: current.itineraryDays,
      schedules: modifiedSchedules,
      reviews: current.reviews,
      averageRating: current.averageRating,
      reviewCount: current.reviewCount,
    );

    emit(
      state.copyWith(
        tourDetail: modified,
        selectedScheduleId: modifiedSchedules.firstOrNull?.scheduleId,
        scheduleError: TourDetailState.msg65,
      ),
    );
  }

  /// Simulates MSG127 system/network failure in Demo Mode.
  void simulateError() {
    if (!isDemoMode) return;
    emit(
      TourDetailState.error(
        TourDetailState.msg127,
        initialSummary: state.initialSummary,
        isDemoMode: true,
      ),
    );
  }

  static TourDetail _getDemoDetail(String tourId, TourSummary? summary) {
    return TourDetail(
      tourId: tourId,
      title:
          summary?.title ??
          'Khám phá Đà Nẵng – Bán đảo Sơn Trà – Ngũ Hành Sơn 3N2Đ',
      description:
          'Hành trình trải nghiệm trọn vẹn vẻ đẹp thành phố biển Đà Nẵng, chiêm ngưỡng tượng Phật Bà Quan Âm cao nhất Việt Nam tại chùa Linh Ứng Sơn Trà, khám phá quần thể hang động Ngũ Hành Sơn huyền bí và thưởng thức ẩm thực miền Trung đặc sắc.',
      destinations: summary?.destinations.isNotEmpty == true
          ? summary!.destinations
          : const ['Đà Nẵng', 'Hội An', 'Sơn Trà'],
      durationDays: summary?.durationDays ?? 3,
      operatorName: summary?.operatorName ?? 'Saigontourist Miền Trung',
      operatorPhone: '1900 1808',
      operatorEmail: 'info@saigontourist.net',
      basePrice: summary?.basePrice ?? 2890000,
      currency: summary?.currency ?? 'VND',
      images: const [
        'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b',
        'https://images.unsplash.com/photo-1528127269322-539801943592',
        'https://images.unsplash.com/photo-1583417319070-4a69db38a482',
      ],
      inclusions: const [
        'Xe du lịch đời mới máy lạnh suốt tuyến',
        'Khách sạn tiêu chuẩn 3 sao (2 khách/phòng)',
        'Các bữa ăn theo chương trình (3 bữa sáng, 5 bữa chính)',
        'Vé tham quan tất cả các điểm trong hành trình',
        'Hướng dẫn viên nhiệt tình, kinh nghiệm suốt tuyến',
        'Bảo hiểm du lịch mức bồi thường tối đa 50.000.000đ/vụ',
        'Nước uống 1 chai 500ml/khách/ngày',
      ],
      exclusions: const [
        'Vé máy bay khứ hồi đến/đi từ Đà Nẵng',
        'Chi phí cá nhân ngoài chương trình (giặt ủi, điện thoại, minibar)',
        'Thuế VAT 8% (nếu yêu cầu xuất hoá đơn)',
        'Tiền tip cho hướng dẫn viên và tài xế',
      ],
      cancellationPolicy:
          '• Huỷ trước 7 ngày khởi hành: Miễn phí hoàn tiền 100%.\n• Huỷ từ 3 - 6 ngày trước khởi hành: Phí huỷ 50% tổng giá trị tour.\n• Huỷ trong vòng 48 giờ trước khởi hành: Không hoàn tiền.',
      itineraryDays: const [
        TourItineraryDay(
          dayNumber: 1,
          title: 'Đón khách – Bán đảo Sơn Trà – Biển Mỹ Khê',
          description:
              'Xe và HDV đón quý khách tại sân bay Đà Nẵng. Đoàn di chuyển đến Bán đảo Sơn Trà, viếng Linh Ứng Tự, tự do tắm biển Mỹ Khê.',
          activities: [
            '08:30 - Đón khách tại sân bay quốc tế Đà Nẵng',
            '10:00 - Tham quan Bán đảo Sơn Trà & chùa Linh Ứng',
            '12:00 - Dùng bữa trưa đặc sản bánh tráng thịt heo',
            '14:00 - Nhận phòng khách sạn nghỉ ngơi',
            '16:30 - Tự do tắm biển Mỹ Khê',
            '18:30 - Thưởng thức bữa tối hải sản ven biển',
          ],
        ),
        TourItineraryDay(
          dayNumber: 2,
          title: 'Ngũ Hành Sơn – Làng Đá Non Nước – Phố Cổ Hội An',
          description:
              'Khám phá danh thắng Ngũ Hành Sơn, động Huyền Không, làng đá mỹ nghệ Non Nước và dạo chơi phố cổ Hội An về đêm rực rỡ đèn lồng.',
          activities: [
            '07:30 - Ăn sáng buffet tại khách sạn',
            '08:30 - Chinh phục Ngũ Hành Sơn, viếng chùa Tam Thai',
            '11:30 - Dùng cơm trưa tại nhà hàng Hội An',
            '14:00 - Tham quan Chùa Cầu, nhà cổ Phùng Hưng',
            '17:00 - Đi thuyền thả hoa đăng trên sông Hoài',
            '19:00 - Tự do khám phá chợ đêm Hội An',
          ],
        ),
        TourItineraryDay(
          dayNumber: 3,
          title: 'Chợ Hàn mua sắm đặc sản – Tiễn sân bay',
          description:
              'Tham quan và mua sắm quà lưu niệm đặc sản miền Trung tại Chợ Hàn. Xe tiễn quý khách ra sân bay Đà Nẵng kết thúc hành trình.',
          activities: [
            '08:00 - Ăn sáng tại khách sạn, làm thủ tục trả phòng',
            '09:00 - Mua sắm tại Chợ Hàn và chợ Cồn',
            '11:30 - Dùng bữa trưa mì Quảng ếch truyền thống',
            '13:30 - Xe tiễn đoàn ra sân bay Đà Nẵng',
          ],
        ),
      ],
      schedules: [
        TourScheduleItem(
          scheduleId: 'sch-001',
          departureAtUtc: DateTime.utc(2026, 10, 15, 2, 0),
          price: 2890000,
          currency: 'VND',
          remainingSlots: 8,
          totalSlots: 20,
          availabilityStatus: AvailabilityStatus.available,
        ),
        TourScheduleItem(
          scheduleId: 'sch-002',
          departureAtUtc: DateTime.utc(2026, 10, 22, 2, 0),
          price: 2890000,
          currency: 'VND',
          remainingSlots: 3,
          totalSlots: 20,
          availabilityStatus: AvailabilityStatus.available,
        ),
        TourScheduleItem(
          scheduleId: 'sch-003',
          departureAtUtc: DateTime.utc(2026, 10, 29, 2, 0),
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
          authorName: 'Nguyễn Văn Minh',
          rating: 5.0,
          comment:
              'Tour tổ chức rất chuyên nghiệp! Hướng dẫn viên vui tính, nhiệt tình, lịch trình hợp lý không bị mệt. Khách sạn và đồ ăn đều rất ngon.',
          createdAtUtc: DateTime.utc(2026, 9, 20, 10, 0),
        ),
        TourReviewItem(
          reviewId: 'rev-02',
          authorName: 'Trần Thị Thuỳ Linh',
          rating: 4.5,
          comment:
              'Cảnh đẹp tuyệt vời, đặc biệt là đêm phố cổ Hội An. Xe đưa đón đúng giờ và bác tài lái xe rất an toàn.',
          createdAtUtc: DateTime.utc(2026, 9, 15, 14, 30),
        ),
      ],
      averageRating: 4.8,
      reviewCount: 24,
    );
  }
}
