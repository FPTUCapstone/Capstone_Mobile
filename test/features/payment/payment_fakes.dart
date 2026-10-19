import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';
import 'package:trip_mate_mobile/features/payment/domain/repositories/payment_repository.dart';

final class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository({
    this.failCreate = false,
    this.failStatus = false,
    this.failMock = false,
    this.failCancel = false,
    this.mockCheckoutUrl = 'https://pay.payos.vn/web/test123',
    this.qrCode,
    this.initialBookingStatus = 'PendingPayment',
    this.initialPaymentStatus = 'Pending',
  });

  bool failCreate;
  bool failStatus;
  bool failMock;
  bool failCancel;
  String mockCheckoutUrl;
  String? qrCode;
  String initialBookingStatus;
  String initialPaymentStatus;

  int createCalls = 0;
  int statusCalls = 0;
  int cancelCalls = 0;
  int mockCalls = 0;

  @override
  Future<PaymentLink> createOrReusePayment(String bookingId) async {
    createCalls++;
    if (failCreate) {
      throw const ServerFailure('Payment link creation failed');
    }
    return PaymentLink(
      paymentId: 101,
      bookingId: bookingId,
      orderCode: 10101,
      amount: 1500000,
      currency: 'VND',
      checkoutUrl: mockCheckoutUrl,
      qrCode: qrCode,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      status: PaymentTransactionStatus.pending,
    );
  }

  @override
  Future<BookingPaymentStatus> getBookingPaymentStatus(String bookingId) async {
    statusCalls++;
    if (failStatus) {
      throw const ServerFailure('Status retrieval failed');
    }
    return BookingPaymentStatus(
      bookingId: bookingId,
      bookingCode: 'BK-TEST',
      bookingStatus: initialBookingStatus,
      paymentStatus: initialPaymentStatus,
      paymentExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
      activePayment: ActivePaymentInfo(
        paymentId: 101,
        gateway: 'PayOS',
        orderCode: 10101,
        amount: 1500000,
        currency: 'VND',
        checkoutUrl: mockCheckoutUrl,
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        status: initialBookingStatus == 'Confirmed'
            ? PaymentTransactionStatus.success
            : (initialBookingStatus == 'Expired'
                  ? PaymentTransactionStatus.expired
                  : (initialBookingStatus == 'Cancelled'
                        ? PaymentTransactionStatus.cancelled
                        : PaymentTransactionStatus.pending)),
      ),
    );
  }

  @override
  Future<void> cancelPayment(String bookingId) async {
    cancelCalls++;
    if (failCancel) {
      throw const ServerFailure('Payment cancellation failed');
    }
    initialBookingStatus = 'Cancelled';
    initialPaymentStatus = 'Cancelled';
  }

  @override
  Future<PaymentTransactionStatus> completeMockPayment({
    required int paymentId,
    required String outcome,
  }) async {
    mockCalls++;
    if (failMock) {
      throw const ServerFailure('Mock completion failed');
    }
    switch (outcome) {
      case 'Success':
        initialBookingStatus = 'Confirmed';
        initialPaymentStatus = 'Paid';
        return PaymentTransactionStatus.success;
      case 'Cancelled':
        initialBookingStatus = 'PendingPayment';
        initialPaymentStatus = 'Pending';
        return PaymentTransactionStatus.cancelled;
      case 'Expired':
        initialBookingStatus = 'Expired';
        initialPaymentStatus = 'Failed';
        return PaymentTransactionStatus.expired;
      default:
        return PaymentTransactionStatus.pending;
    }
  }
}
