import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_contact.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';
import 'package:trip_mate_mobile/features/booking/domain/repositories/booking_repository.dart';

final class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._remote);
  final BookingRemoteDataSource _remote;

  /// Every remote failure is mapped to a user-safe [Failure]; raw backend text never reaches the UI.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<BookingContact> getBookingContact() =>
      _guard(_remote.getBookingContact);

  @override
  Future<BookingQuote> quote({
    required String tourScheduleId,
    required ParticipantCounts participantCounts,
    String? voucherCode,
  }) => _guard(
    () => _remote.quote(
      tourScheduleId: tourScheduleId,
      participantCounts: participantCounts,
      voucherCode: voucherCode,
    ),
  );

  @override
  Future<TourBooking> createBooking({
    required String tourScheduleId,
    required List<BookingParticipant> participants,
    required String idempotencyKey,
    String? voucherCode,
  }) => _guard(
    () => _remote.createBooking(
      tourScheduleId: tourScheduleId,
      participants: participants,
      idempotencyKey: idempotencyKey,
      voucherCode: voucherCode,
    ),
  );
}
