import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/booking_refund/data/datasources/booking_refund_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/repositories/booking_refund_repository.dart';

final class BookingRefundRepositoryImpl implements BookingRefundRepository {
  const BookingRefundRepositoryImpl(this._remote);
  final BookingRefundRemoteDataSource _remote;

  @override
  Future<BookingRefundProgress> getProgress(String bookingId) async {
    try {
      return await _remote.getProgress(bookingId);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
