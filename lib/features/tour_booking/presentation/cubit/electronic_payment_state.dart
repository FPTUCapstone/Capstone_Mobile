import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';

enum ElectronicPaymentStatus {
  initial,
  loading,
  ready,
  unauthorized,
  pendingIntegration,
  error,
}

final class ElectronicPaymentState extends Equatable {
  const ElectronicPaymentState({
    required this.status,
    required this.bookingId,
    this.booking,
    this.selectedMethod = PaymentGatewayMethod.vnpay,
    this.remainingPaymentDuration = const Duration(minutes: 15),
    this.noticeMessage,
    this.isErrorNotice = false,
    this.errorMessage,
    this.isDemoMode = false,
  });

  // Canonical messages for UC-28
  static const String msg80 =
      'The payment window has expired and this booking is no longer active.';
  static const String msg81 = 'The booking has been cancelled.';
  static const String msg85 =
      'Redirecting to the payment gateway. Please complete the transaction.';
  static const String msg86 =
      'Payment completed successfully. Your booking is now confirmed.';
  static const String msg87 =
      'Payment was not completed. Your booking remains unpaid while the payment window is still active.';
  static const String msg88 = 'This booking has already been paid.';
  static const String msg89 =
      'Unable to connect to the payment gateway. Please try again while your booking remains active.';
  static const String msg90 =
      'Payment status has not been confirmed yet. Please wait or refresh your booking status.';
  static const String msg91 =
      'This payment notification has already been processed or could not be matched to an active transaction.';
  static const String msg92 =
      'Payment verification requires manual reconciliation. Your booking has not been confirmed yet.';
  static const String msg126 = 'You are not allowed to perform this action.';
  static const String msg127 =
      'A system error occurred. Please try again later.';

  final ElectronicPaymentStatus status;
  final String bookingId;
  final TourBookingRecord? booking;
  final PaymentGatewayMethod selectedMethod;
  final Duration remainingPaymentDuration;
  final String? noticeMessage;
  final bool isErrorNotice;
  final String? errorMessage;
  final bool isDemoMode;

  bool get isExpired =>
      booking?.status == BookingLifecycleStatus.expired ||
      (booking?.status == BookingLifecycleStatus.pendingPayment &&
          remainingPaymentDuration <= Duration.zero);

  bool get isCancelled => booking?.status == BookingLifecycleStatus.cancelled;

  bool get isConfirmed => booking?.status == BookingLifecycleStatus.confirmed;

  bool get canProceedToPayment =>
      isDemoMode &&
      status == ElectronicPaymentStatus.ready &&
      booking?.status == BookingLifecycleStatus.pendingPayment &&
      remainingPaymentDuration > Duration.zero;

  bool get canCancelBooking =>
      isDemoMode &&
      status == ElectronicPaymentStatus.ready &&
      booking?.status == BookingLifecycleStatus.pendingPayment &&
      remainingPaymentDuration > Duration.zero;

  ElectronicPaymentState copyWith({
    ElectronicPaymentStatus? status,
    TourBookingRecord? booking,
    PaymentGatewayMethod? selectedMethod,
    Duration? remainingPaymentDuration,
    String? noticeMessage,
    bool clearNoticeMessage = false,
    bool? isErrorNotice,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isDemoMode,
  }) {
    return ElectronicPaymentState(
      status: status ?? this.status,
      bookingId: bookingId,
      booking: booking ?? this.booking,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      remainingPaymentDuration:
          remainingPaymentDuration ?? this.remainingPaymentDuration,
      noticeMessage: clearNoticeMessage
          ? null
          : (noticeMessage ?? this.noticeMessage),
      isErrorNotice: isErrorNotice ?? this.isErrorNotice,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    bookingId,
    booking,
    selectedMethod,
    remainingPaymentDuration,
    noticeMessage,
    isErrorNotice,
    errorMessage,
    isDemoMode,
  ];
}
