import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_contact_info.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/tour_booking_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// Cubit managing UC-27 Book Tour (Screen #66).
///
/// Production Truthfulness (`!isDemoMode`):
/// Because the canonical Backend currently has no tour booking endpoints (`NO_BACKEND`),
/// production mode strictly emits [TourBookingStatus.pendingIntegration] and never
/// creates fake bookings, fake slot holds, or client-authoritative voucher discounts.
final class TourBookingCubit extends Cubit<TourBookingState> {
  TourBookingCubit({
    required String tourId,
    this.initialScheduleId,
    TourDetail? initialDetail,
    TourSummary? initialSummary,
    this.isDemoMode = false,
    DemoBookingFunnelStore? demoStore,
  }) : _demoStore = demoStore ?? DemoBookingFunnelStore.instance,
       super(
         TourBookingState(
           status: TourBookingStatus.initial,
           tourId: tourId,
           initialDetail: initialDetail,
           initialSummary: initialSummary,
           isDemoMode: isDemoMode,
         ),
       );

  final String? initialScheduleId;
  final bool isDemoMode;
  final DemoBookingFunnelStore _demoStore;

  /// Loads the booking form state.
  Future<void> load() async {
    emit(state.copyWith(status: TourBookingStatus.loading));

    if (!isDemoMode) {
      // Production mode: Never fabricate a booking, schedule, or discount.
      emit(
        state.copyWith(
          status: TourBookingStatus.pendingIntegration,
          clearValidationMessage: true,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final detail = state.initialDetail ?? _buildDemoDetail(state.tourId);
    final schedule = _resolveSchedule(detail, initialScheduleId);
    final reservedSlots = schedule != null
        ? _demoStore.reservedSlotsForSchedule(schedule.scheduleId)
        : 0;
    final rawRemaining = (schedule?.remainingSlots ?? 0) - reservedSlots;
    final effectiveRemaining = rawRemaining < 0 ? 0 : rawRemaining;

    final isUnavailable =
        schedule == null || schedule.isSoldOut || effectiveRemaining <= 0;

    emit(
      state.copyWith(
        status: TourBookingStatus.ready,
        initialDetail: detail,
        selectedSchedule: schedule,
        effectiveRemainingSlots: effectiveRemaining,
        participantCount: 1,
        participants: const [_defaultFirstParticipant],
        contactInfo: _defaultContactInfo,
        simulateInsufficientSlotsOnConfirm: false,
        validationMessage: isUnavailable ? TourBookingState.msg65 : null,
        clearValidationMessage: !isUnavailable,
        clearErrorMessage: true,
        clearStatusMessage: true,
      ),
    );
  }

  /// Updates the requested number of participants and resizes the participant cards list.
  /// Enforces remaining slot check (`MSG77`) when requested count exceeds remaining slots.
  void setParticipantCount(int count) {
    if (!isDemoMode || state.status != TourBookingStatus.ready) return;
    if (count < 1) return;

    if (state.isScheduleUnavailable) {
      emit(state.copyWith(validationMessage: TourBookingState.msg65));
      return;
    }

    if (count > state.effectiveRemainingSlots) {
      emit(state.copyWith(validationMessage: TourBookingState.msg77));
      return;
    }

    final currentList = List<BookingParticipant>.from(state.participants);
    while (currentList.length < count) {
      final index = currentList.length + 1;
      currentList.add(
        BookingParticipant(
          fullName: 'Khách tham gia $index',
          dateOfBirth: '10/10/1995',
          identityDocumentNumber:
              '0480950012${index.toString().padLeft(2, '0')}',
          phoneNumber: '09051112${index.toString().padLeft(2, '0')}',
        ),
      );
    }
    if (currentList.length > count) {
      currentList.removeRange(count, currentList.length);
    }

    final nextSubtotal = state.unitPrice * count;
    var nextDiscount = state.discountAmount;
    String? nextCode = state.appliedVoucherCode;
    String? nextVoucherNotice = state.voucherNotice;
    var nextIsVoucherError = state.isVoucherError;

    // Revalidate applied voucher when subtotal changes (BR-97..BR-100).
    if (nextCode != null) {
      final eval = _demoStore.evaluateVoucher(
        rawCode: nextCode,
        subtotal: nextSubtotal,
      );
      if (eval.isValid) {
        nextDiscount = eval.discountAmount;
      } else {
        nextCode = null;
        nextDiscount = 0;
        nextVoucherNotice = eval.message;
        nextIsVoucherError = true;
      }
    }

    emit(
      state.copyWith(
        participantCount: count,
        participants: List.unmodifiable(currentList),
        appliedVoucherCode: nextCode,
        clearAppliedVoucher: nextCode == null,
        discountAmount: nextDiscount,
        voucherNotice: nextVoucherNotice,
        isVoucherError: nextIsVoucherError,
        clearValidationMessage: true,
      ),
    );
  }

  /// Updates a single participant's information at [index].
  void updateParticipant(int index, BookingParticipant participant) {
    if (!isDemoMode) return;
    if (index < 0 || index >= state.participants.length) return;
    final updated = List<BookingParticipant>.from(state.participants);
    updated[index] = participant;
    emit(
      state.copyWith(
        participants: List.unmodifiable(updated),
        clearValidationMessage: true,
      ),
    );
  }

  /// Updates primary contact information.
  void updateContactInfo(BookingContactInfo contactInfo) {
    if (!isDemoMode) return;
    emit(
      state.copyWith(contactInfo: contactInfo, clearValidationMessage: true),
    );
  }

  /// Updates the raw voucher code input text.
  void setVoucherInput(String value) {
    if (!isDemoMode) return;
    emit(
      state.copyWith(
        voucherInput: value,
        clearVoucherNotice: true,
        isVoucherError: false,
      ),
    );
  }

  /// Applies the entered promotional voucher code (`BR-97`, `BR-98`, `BR-99`, `BR-100`).
  void applyVoucher() {
    if (!isDemoMode || state.status != TourBookingStatus.ready) return;

    final raw = state.voucherInput.trim();
    if (raw.isEmpty) {
      emit(
        state.copyWith(
          voucherNotice: TourBookingState.msg01,
          isVoucherError: true,
        ),
      );
      return;
    }

    final eval = _demoStore.evaluateVoucher(
      rawCode: raw,
      subtotal: state.subtotal,
    );

    if (!eval.isValid) {
      emit(
        state.copyWith(
          clearAppliedVoucher: true,
          discountAmount: 0,
          voucherNotice: eval.message ?? TourBookingState.msg101,
          isVoucherError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        voucherInput: eval.normalizedCode ?? raw.toUpperCase(),
        appliedVoucherCode: eval.normalizedCode,
        discountAmount: eval.discountAmount,
        voucherNotice: TourBookingState.msg100,
        isVoucherError: false,
      ),
    );
  }

  /// Removes the currently applied voucher and restores the original subtotal (`MSG103`).
  void removeVoucher() {
    if (!isDemoMode || state.appliedVoucherCode == null) return;
    emit(
      state.copyWith(
        voucherInput: '',
        clearAppliedVoucher: true,
        discountAmount: 0,
        voucherNotice: TourBookingState.msg103,
        isVoucherError: false,
      ),
    );
  }

  /// Validates the booking form before opening the CR-05 confirmation dialog.
  /// Returns `true` if valid and ready to confirm, or `false` after emitting the
  /// canonical validation message (`MSG01`, `MSG65`, `MSG77`, `MSG78`, `MSG126`).
  bool validateBeforeConfirmation() {
    if (!isDemoMode) return false;

    if (state.isScheduleUnavailable) {
      emit(state.copyWith(validationMessage: TourBookingState.msg65));
      return false;
    }

    if (state.participantCount > state.effectiveRemainingSlots) {
      emit(state.copyWith(validationMessage: TourBookingState.msg77));
      return false;
    }

    // Check required fields first (MSG01)
    if (state.contactInfo.hasEmptyRequiredField ||
        state.participants.any((p) => p.hasEmptyRequiredField)) {
      emit(state.copyWith(validationMessage: TourBookingState.msg01));
      return false;
    }

    // Check participant & contact format rules (MSG78)
    if (!state.contactInfo.hasValidFormat ||
        state.participants.any((p) => !p.hasValidFormat)) {
      emit(state.copyWith(validationMessage: TourBookingState.msg78));
      return false;
    }

    // Check concurrent unpaid bookings limit (BR-67 -> MSG126)
    if (_demoStore.hasReachedMaxConcurrentUnpaidBookings()) {
      emit(state.copyWith(validationMessage: TourBookingState.msg126));
      return false;
    }

    emit(state.copyWith(clearValidationMessage: true));
    return true;
  }

  /// Confirms and creates a `Pending Payment` booking after the user accepts CR-05.
  Future<void> confirmBooking() async {
    if (!isDemoMode) return;
    if (!validateBeforeConfirmation()) return;

    // Revalidate schedule and remaining slots at commit time (E1 / E2 -> MSG65 / MSG77).
    if (state.simulateInsufficientSlotsOnConfirm) {
      emit(
        state.copyWith(
          effectiveRemainingSlots: 0,
          validationMessage: TourBookingState.msg77,
        ),
      );
      return;
    }

    final schedule = state.selectedSchedule;
    final detail = state.initialDetail;
    if (schedule == null || detail == null || schedule.isSoldOut) {
      emit(state.copyWith(validationMessage: TourBookingState.msg65));
      return;
    }

    final reservedNow = _demoStore.reservedSlotsForSchedule(
      schedule.scheduleId,
    );
    final remainingNow = schedule.remainingSlots - reservedNow;
    if (remainingNow <= 0) {
      emit(
        state.copyWith(
          effectiveRemainingSlots: 0,
          validationMessage: TourBookingState.msg65,
        ),
      );
      return;
    }
    if (state.participantCount > remainingNow) {
      emit(
        state.copyWith(
          effectiveRemainingSlots: remainingNow,
          validationMessage: TourBookingState.msg77,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TourBookingStatus.submitting,
        clearValidationMessage: true,
      ),
    );

    final record = _demoStore.createPendingBooking(
      tourId: detail.tourId,
      tourTitle: detail.title,
      operatorName: detail.operatorName,
      scheduleId: schedule.scheduleId,
      departureAtUtc: schedule.departureAtUtc,
      durationDays: detail.durationDays,
      meetingPoint: 'Sân bay Quốc tế Đà Nẵng (Cổng ga đến quốc nội A2)',
      participantCount: state.participantCount,
      participants: state.participants,
      contactInfo: state.contactInfo,
      unitPrice: state.unitPrice,
      discountAmount: state.clampedDiscount,
      appliedVoucherCode: state.appliedVoucherCode,
    );

    final nextRemaining = remainingNow - state.participantCount;

    emit(
      state.copyWith(
        status: TourBookingStatus.bookingCreated,
        createdBooking: record,
        effectiveRemainingSlots: nextRemaining < 0 ? 0 : nextRemaining,
        statusMessage: TourBookingState.msg79,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Demo Simulation Controls (Debug + ?demo=true only)
  // ───────────────────────────────────────────────────────────────────────────

  void simulateScheduleSoldOut() {
    if (!isDemoMode || state.selectedSchedule == null) return;
    final soldOutSchedule = TourScheduleItem(
      scheduleId: state.selectedSchedule!.scheduleId,
      departureAtUtc: state.selectedSchedule!.departureAtUtc,
      price: state.selectedSchedule!.price,
      currency: state.selectedSchedule!.currency,
      remainingSlots: 0,
      totalSlots: state.selectedSchedule!.totalSlots,
      availabilityStatus: AvailabilityStatus.soldOut,
    );
    emit(
      state.copyWith(
        status: TourBookingStatus.ready,
        selectedSchedule: soldOutSchedule,
        effectiveRemainingSlots: 0,
        validationMessage: TourBookingState.msg65,
      ),
    );
  }

  void simulateInsufficientSlotsAtRevalidation() {
    if (!isDemoMode) return;
    emit(
      state.copyWith(
        status: TourBookingStatus.ready,
        simulateInsufficientSlotsOnConfirm: true,
        validationMessage: TourBookingState.msg77,
      ),
    );
  }

  void simulateMaxUnpaidBookingsReached() {
    if (!isDemoMode) return;
    _demoStore.setSimulateMaxUnpaidReached(true);
    emit(
      state.copyWith(
        status: TourBookingStatus.ready,
        validationMessage: TourBookingState.msg126,
      ),
    );
  }

  void simulateIncompleteParticipant() {
    if (!isDemoMode || state.participants.isEmpty) return;
    final updated = List<BookingParticipant>.from(state.participants);
    updated[0] = updated[0].copyWith(identityDocumentNumber: '123');
    emit(
      state.copyWith(
        status: TourBookingStatus.ready,
        participants: List.unmodifiable(updated),
        validationMessage: TourBookingState.msg78,
      ),
    );
  }

  void simulateError() {
    if (!isDemoMode) return;
    emit(
      state.copyWith(
        status: TourBookingStatus.error,
        errorMessage: TourBookingState.msg127,
      ),
    );
  }

  void resetDemoSimulations() {
    if (!isDemoMode) return;
    _demoStore.setSimulateMaxUnpaidReached(false);
    load();
  }

  static const BookingParticipant _defaultFirstParticipant = BookingParticipant(
    fullName: 'Nguyễn Minh Quân',
    dateOfBirth: '15/05/1996',
    identityDocumentNumber: '048096001234',
    phoneNumber: '0905123456',
  );

  static const BookingContactInfo _defaultContactInfo = BookingContactInfo(
    fullName: 'Nguyễn Minh Quân',
    email: 'minhquan.traveler@example.com',
    phoneNumber: '0905123456',
  );

  static TourScheduleItem? _resolveSchedule(
    TourDetail detail,
    String? requestedScheduleId,
  ) {
    if (requestedScheduleId != null && requestedScheduleId.isNotEmpty) {
      final match = detail.schedules
          .where((s) => s.scheduleId == requestedScheduleId)
          .firstOrNull;
      if (match != null) return match;
    }
    return detail.schedules.where((s) => !s.isSoldOut).firstOrNull ??
        detail.schedules.firstOrNull;
  }

  static TourDetail _buildDemoDetail(String tourId) {
    return TourDetail(
      tourId: tourId,
      title: 'Khám phá Đà Nẵng – Bán đảo Sơn Trà – Ngũ Hành Sơn 3N2Đ',
      description:
          'Hành trình trải nghiệm trọn vẹn vẻ đẹp thành phố biển Đà Nẵng, chùa Linh Ứng Sơn Trà, Ngũ Hành Sơn và phố cổ Hội An.',
      destinations: const ['Đà Nẵng', 'Hội An', 'Sơn Trà'],
      durationDays: 3,
      operatorName: 'Saigontourist Miền Trung',
      operatorPhone: '1900 1808',
      operatorEmail: 'info@saigontourist.net',
      basePrice: 2890000,
      currency: 'VND',
      cancellationPolicy:
          'Huỷ trước 7 ngày khởi hành: Hoàn 100%. Huỷ trong 48 giờ: Không hoàn tiền.',
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
      ],
    );
  }
}
