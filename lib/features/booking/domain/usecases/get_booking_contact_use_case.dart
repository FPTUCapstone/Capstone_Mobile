import 'package:trip_mate_mobile/features/booking/domain/entities/booking_contact.dart';
import 'package:trip_mate_mobile/features/booking/domain/repositories/booking_repository.dart';

final class GetBookingContactUseCase {
  const GetBookingContactUseCase(this._repository);
  final BookingRepository _repository;

  Future<BookingContact> call() => _repository.getBookingContact();
}
