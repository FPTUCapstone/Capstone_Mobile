import 'package:trip_mate_mobile/features/booking_cancellation/data/datasources/booking_cancellation_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_preview.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/repositories/booking_cancellation_repository.dart';

final class BookingCancellationRepositoryImpl
    implements BookingCancellationRepository {
  const BookingCancellationRepositoryImpl(this._remote);
  final BookingCancellationRemoteDataSource _remote;

  @override
  Future<BookingCancellationPreview> getPreview(int bookingId) async {
    try {
      return await _remote.getPreview(bookingId);
    } on BookingCancellationFailure {
      rethrow;
    } on Object {
      throw const BookingCancellationFailure(
        BookingCancellationFailureKind.system,
      );
    }
  }

  @override
  Future<void> cancel(
    int bookingId, {
    String? reasonCategory,
    String? reasonDetail,
    required bool confirmed,
    required String idempotencyKey,
  }) async {
    try {
      await _remote.cancel(
        bookingId,
        reasonCategory: reasonCategory,
        reasonDetail: reasonDetail,
        confirmed: confirmed,
        idempotencyKey: idempotencyKey,
      );
    } on BookingCancellationFailure {
      rethrow;
    } on Object {
      throw const BookingCancellationFailure(
        BookingCancellationFailureKind.system,
      );
    }
  }
}
