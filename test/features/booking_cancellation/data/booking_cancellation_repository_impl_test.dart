import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/data/datasources/booking_cancellation_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/data/repositories/booking_cancellation_repository_impl.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_preview.dart';

final _preview = BookingCancellationPreview(
  bookingId: 42,
  tourTitle: 'Hoi An Lantern Tour',
  bookingStatus: 'Confirmed',
  paymentStatus: 'Paid',
  totalAmount: 1000000,
  canCancel: true,
  estimatedRefundAmount: 300000,
  refundStatus: 'Pending',
);

final class _FakeDataSource implements BookingCancellationRemoteDataSource {
  _FakeDataSource({this.previewError, this.cancelError});

  final Object? previewError;
  final Object? cancelError;

  @override
  Future<BookingCancellationPreview> getPreview(int bookingId) async {
    final error = previewError;
    if (error != null) throw error;
    return _preview;
  }

  @override
  Future<void> cancel(
    int bookingId, {
    String? reasonCategory,
    String? reasonDetail,
    required bool confirmed,
    required String idempotencyKey,
  }) async {
    final error = cancelError;
    if (error != null) throw error;
  }
}

void main() {
  test('returns the preview from the data source unchanged', () async {
    final repository = BookingCancellationRepositoryImpl(_FakeDataSource());

    final preview = await repository.getPreview(42);

    expect(preview, _preview);
  });

  test(
    'passes through a BookingCancellationFailure from the data source',
    () async {
      final repository = BookingCancellationRepositoryImpl(
        _FakeDataSource(
          previewError: const BookingCancellationFailure(
            BookingCancellationFailureKind.notFound,
          ),
        ),
      );

      await expectLater(
        repository.getPreview(42),
        throwsA(
          const BookingCancellationFailure(
            BookingCancellationFailureKind.notFound,
          ),
        ),
      );
    },
  );

  test('maps an unexpected exception from the data source to system', () async {
    final repository = BookingCancellationRepositoryImpl(
      _FakeDataSource(cancelError: StateError('unexpected')),
    );

    await expectLater(
      repository.cancel(42, confirmed: true, idempotencyKey: 'key'),
      throwsA(
        const BookingCancellationFailure(BookingCancellationFailureKind.system),
      ),
    );
  });
}
