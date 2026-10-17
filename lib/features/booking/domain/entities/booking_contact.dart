import 'package:equatable/equatable.dart';

/// Contact fields that may be safely prefilled for the lead traveler from the
/// authenticated Traveler profile. The booking form remains editable.
final class BookingContact extends Equatable {
  const BookingContact({required this.fullName, this.phoneNumber, this.email});

  final String fullName;
  final String? phoneNumber;
  final String? email;

  @override
  List<Object?> get props => [fullName, phoneNumber, email];
}
