import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_contact_info.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

enum TourBookingStatus {
  initial,
  loading,
  ready,
  submitting,
  bookingCreated,
  pendingIntegration,
  error,
}

final class TourBookingState extends Equatable {
  const TourBookingState({
    required this.status,
    required this.tourId,
    this.initialDetail,
    this.initialSummary,
    this.selectedSchedule,
    this.effectiveRemainingSlots = 0,
    this.participantCount = 1,
    this.participants = const [BookingParticipant()],
    this.contactInfo = const BookingContactInfo(),
    this.voucherInput = '',
    this.appliedVoucherCode,
    this.discountAmount = 0,
    this.voucherNotice,
    this.isVoucherError = false,
    this.validationMessage,
    this.statusMessage,
    this.errorMessage,
    this.createdBooking,
    this.simulateInsufficientSlotsOnConfirm = false,
    this.isDemoMode = false,
  });

  // Canonical messages for UC-27
  static const String msg01 = 'Please fill in all required fields.';
  static const String msg65 =
      'This tour or departure schedule is no longer available.';
  static const String msg77 =
      'The requested number of participants exceeds the remaining slots.';
  static const String msg78 =
      'Participant information is incomplete or invalid. Please review and try again.';
  static const String msg79 =
      'Your booking has been created. Please complete payment within 15 minutes to confirm your reservation.';
  static const String msg100 = 'The voucher has been applied successfully.';
  static const String msg101 =
      'The voucher code is invalid, expired, or no longer available.';
  static const String msg102 =
      'The booking does not meet the minimum spend requirement for this voucher.';
  static const String msg103 = 'The applied voucher has been removed.';
  static const String msg126 = 'You are not allowed to perform this action.';
  static const String msg127 =
      'A system error occurred. Please try again later.';

  final TourBookingStatus status;
  final String tourId;
  final TourDetail? initialDetail;
  final TourSummary? initialSummary;
  final TourScheduleItem? selectedSchedule;
  final int effectiveRemainingSlots;
  final int participantCount;
  final List<BookingParticipant> participants;
  final BookingContactInfo contactInfo;
  final String voucherInput;
  final String? appliedVoucherCode;
  final int discountAmount;
  final String? voucherNotice;
  final bool isVoucherError;
  final String? validationMessage;
  final String? statusMessage;
  final String? errorMessage;
  final TourBookingRecord? createdBooking;
  final bool simulateInsufficientSlotsOnConfirm;
  final bool isDemoMode;

  int get unitPrice =>
      selectedSchedule?.price ??
      initialDetail?.basePrice ??
      initialSummary?.basePrice ??
      0;

  int get subtotal => unitPrice * participantCount;

  /// BR-100: Discount never exceeds subtotal; total amount never becomes negative.
  int get clampedDiscount => discountAmount > subtotal
      ? subtotal
      : (discountAmount < 0 ? 0 : discountAmount);

  int get totalAmount => subtotal - clampedDiscount;

  DateTime? get departureAtUtc => selectedSchedule?.departureAtUtc;

  DateTime? get returnAtUtc {
    final departure = departureAtUtc;
    if (departure == null) return null;
    final days =
        initialDetail?.durationDays ?? initialSummary?.durationDays ?? 3;
    return departure.add(Duration(days: days));
  }

  bool get isScheduleUnavailable =>
      selectedSchedule == null ||
      selectedSchedule!.isSoldOut ||
      effectiveRemainingSlots <= 0;

  TourBookingState copyWith({
    TourBookingStatus? status,
    TourDetail? initialDetail,
    TourSummary? initialSummary,
    TourScheduleItem? selectedSchedule,
    int? effectiveRemainingSlots,
    int? participantCount,
    List<BookingParticipant>? participants,
    BookingContactInfo? contactInfo,
    String? voucherInput,
    String? appliedVoucherCode,
    bool clearAppliedVoucher = false,
    int? discountAmount,
    String? voucherNotice,
    bool clearVoucherNotice = false,
    bool? isVoucherError,
    String? validationMessage,
    bool clearValidationMessage = false,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    TourBookingRecord? createdBooking,
    bool? simulateInsufficientSlotsOnConfirm,
    bool? isDemoMode,
  }) {
    return TourBookingState(
      status: status ?? this.status,
      tourId: tourId,
      initialDetail: initialDetail ?? this.initialDetail,
      initialSummary: initialSummary ?? this.initialSummary,
      selectedSchedule: selectedSchedule ?? this.selectedSchedule,
      effectiveRemainingSlots:
          effectiveRemainingSlots ?? this.effectiveRemainingSlots,
      participantCount: participantCount ?? this.participantCount,
      participants: participants ?? this.participants,
      contactInfo: contactInfo ?? this.contactInfo,
      voucherInput: voucherInput ?? this.voucherInput,
      appliedVoucherCode: clearAppliedVoucher
          ? null
          : (appliedVoucherCode ?? this.appliedVoucherCode),
      discountAmount: discountAmount ?? this.discountAmount,
      voucherNotice: clearVoucherNotice
          ? null
          : (voucherNotice ?? this.voucherNotice),
      isVoucherError: isVoucherError ?? this.isVoucherError,
      validationMessage: clearValidationMessage
          ? null
          : (validationMessage ?? this.validationMessage),
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      createdBooking: createdBooking ?? this.createdBooking,
      simulateInsufficientSlotsOnConfirm:
          simulateInsufficientSlotsOnConfirm ??
          this.simulateInsufficientSlotsOnConfirm,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    tourId,
    initialDetail,
    initialSummary,
    selectedSchedule,
    effectiveRemainingSlots,
    participantCount,
    participants,
    contactInfo,
    voucherInput,
    appliedVoucherCode,
    discountAmount,
    voucherNotice,
    isVoucherError,
    validationMessage,
    statusMessage,
    errorMessage,
    createdBooking,
    simulateInsufficientSlotsOnConfirm,
    isDemoMode,
  ];
}
