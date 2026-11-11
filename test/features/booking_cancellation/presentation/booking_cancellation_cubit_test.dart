import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_preview.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/repositories/booking_cancellation_repository.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/usecases/cancel_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/usecases/get_booking_cancellation_preview_use_case.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/presentation/cubit/booking_cancellation_cubit.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/presentation/cubit/booking_cancellation_state.dart';

BookingCancellationPreview preview({
  bool canCancel = true,
  String? blockingReasonCode,
  double estimatedRefundAmount = 300000,
}) => BookingCancellationPreview(
  bookingId: 42,
  tourTitle: 'Hoi An Lantern Tour',
  bookingStatus: 'Confirmed',
  paymentStatus: 'Paid',
  totalAmount: 1000000,
  canCancel: canCancel,
  blockingReasonCode: blockingReasonCode,
  estimatedRefundAmount: estimatedRefundAmount,
  refundStatus: estimatedRefundAmount > 0 ? 'Pending' : 'NotRequired',
);

final class FakeBookingCancellationRepository
    implements BookingCancellationRepository {
  final List<Object> previewReads = [];
  final List<Object?> cancelCalls = [];
  final List<String> idempotencyKeysSeen = [];

  @override
  Future<BookingCancellationPreview> getPreview(int bookingId) async {
    final next = previewReads.removeAt(0);
    if (next is BookingCancellationFailure) throw next;
    return next as BookingCancellationPreview;
  }

  @override
  Future<void> cancel(
    int bookingId, {
    String? reasonCategory,
    String? reasonDetail,
    required bool confirmed,
    required String idempotencyKey,
  }) async {
    idempotencyKeysSeen.add(idempotencyKey);
    final next = cancelCalls.removeAt(0);
    if (next is BookingCancellationFailure) throw next;
  }
}

BookingCancellationCubit buildCubit(
  FakeBookingCancellationRepository repository, {
  int bookingId = 42,
}) => BookingCancellationCubit(
  bookingId: bookingId,
  getPreview: GetBookingCancellationPreviewUseCase(repository),
  cancel: CancelBookingUseCase(repository),
);

void main() {
  late FakeBookingCancellationRepository repository;

  setUp(() {
    repository = FakeBookingCancellationRepository();
  });

  test('loads the preview and becomes ready', () async {
    repository.previewReads.add(preview());
    final cubit = buildCubit(repository);

    await cubit.load();

    expect(cubit.state.phase, BookingCancellationPhase.ready);
    expect(cubit.state.preview?.estimatedRefundAmount, 300000);
    expect(cubit.state.canSubmit, isTrue);
  });

  test('goes to failure phase when the preview fails to load', () async {
    repository.previewReads.add(
      const BookingCancellationFailure(BookingCancellationFailureKind.notFound),
    );
    final cubit = buildCubit(repository);

    await cubit.load();

    expect(cubit.state.phase, BookingCancellationPhase.failure);
    expect(cubit.state.failure, BookingCancellationFailureKind.notFound);
  });

  test(
    'a refund above zero can be submitted without ticking confirmation',
    () async {
      repository.previewReads.add(preview());
      final cubit = buildCubit(repository);
      await cubit.load();

      expect(cubit.state.needsConfirmation, isFalse);
      expect(cubit.state.canSubmit, isTrue);
    },
  );

  test(
    'a zero refund blocks submission at the cubit level until confirmed is ticked',
    () async {
      repository.previewReads.add(
        preview(
          blockingReasonCode: 'booking.cancellation.confirmation_required',
          estimatedRefundAmount: 0,
        ),
      );
      final cubit = buildCubit(repository);
      await cubit.load();

      expect(cubit.state.needsConfirmation, isTrue);
      expect(cubit.state.canSubmit, isFalse);

      cubit.toggleConfirmed(true);

      expect(cubit.state.canSubmit, isTrue);
    },
  );

  test('submit succeeds and reaches the success phase', () async {
    repository.previewReads.add(preview());
    repository.cancelCalls.add(null);
    final cubit = buildCubit(repository);
    await cubit.load();

    await cubit.submit();

    expect(cubit.state.phase, BookingCancellationPhase.success);
  });

  test('the idempotency key does not change between submit attempts', () async {
    repository.previewReads.add(preview());
    repository.cancelCalls.addAll([
      const BookingCancellationFailure(BookingCancellationFailureKind.system),
      null,
    ]);
    final cubit = buildCubit(repository);
    await cubit.load();

    await cubit.submit();
    await cubit.submit();

    expect(repository.idempotencyKeysSeen, hasLength(2));
    expect(
      repository.idempotencyKeysSeen[0],
      repository.idempotencyKeysSeen[1],
    );
  });

  test('a failed submit keeps the preview so the user can retry', () async {
    repository.previewReads.add(preview());
    repository.cancelCalls.add(
      const BookingCancellationFailure(BookingCancellationFailureKind.system),
    );
    final cubit = buildCubit(repository);
    await cubit.load();

    await cubit.submit();

    expect(cubit.state.phase, BookingCancellationPhase.failure);
    expect(cubit.state.preview, isNotNull);
    expect(cubit.state.failure, BookingCancellationFailureKind.system);
  });
}
