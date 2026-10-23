import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/repositories/booking_refund_repository.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/usecases/get_booking_refund_progress_use_case.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_state.dart';

void main() {
  test('loads the refund progress for the supplied booking id', () async {
    final repository = _FakeRepository();
    final cubit = BookingRefundProgressCubit(
      getProgress: GetBookingRefundProgressUseCase(repository),
    );

    await cubit.load('42');

    expect(repository.bookingId, '42');
    expect(cubit.state.status, BookingRefundProgressStatus.success);
    expect(cubit.state.progress?.status, BookingRefundStatus.retryPending);
    await cubit.close();
  });

  test('exposes a safe failure when the progress request fails', () async {
    final cubit = BookingRefundProgressCubit(
      getProgress: GetBookingRefundProgressUseCase(
        _FakeRepository(fails: true),
      ),
    );

    await cubit.load('42');

    expect(cubit.state.status, BookingRefundProgressStatus.failure);
    expect(cubit.state.failure?.message, 'The refund could not be found.');
    await cubit.close();
  });
}

final class _FakeRepository implements BookingRefundRepository {
  _FakeRepository({this.fails = false});
  final bool fails;
  String? bookingId;

  @override
  Future<BookingRefundProgress> getProgress(String requestedBookingId) async {
    bookingId = requestedBookingId;
    if (fails) throw const NotFoundFailure('The refund could not be found.');
    return BookingRefundProgress(
      bookingId: 42,
      bookingCode: 'BK-20261022-00042',
      refundAmount: 500000,
      status: BookingRefundStatus.retryPending,
      attemptCount: 1,
      requestedAtUtc: DateTime.utc(2026, 10, 22, 8),
      nextAttemptAtUtc: DateTime.utc(2026, 10, 22, 8, 5),
    );
  }
}
