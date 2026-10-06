import 'package:equatable/equatable.dart';

/// Represents primary contact information for a Tour Booking (UC-27).
final class BookingContactInfo extends Equatable {
  const BookingContactInfo({
    this.fullName = '',
    this.email = '',
    this.phoneNumber = '',
  });

  final String fullName;
  final String email;
  final String phoneNumber;

  bool get hasEmptyRequiredField =>
      fullName.trim().isEmpty ||
      email.trim().isEmpty ||
      phoneNumber.trim().isEmpty;

  bool get hasValidFormat {
    if (hasEmptyRequiredField) return false;
    if (fullName.trim().length < 2) return false;

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email.trim())) return false;

    final normalizedPhone = phoneNumber.trim().replaceAll(' ', '');
    final phonePattern = RegExp(r'^\+?\d{9,15}$');
    if (!phonePattern.hasMatch(normalizedPhone)) return false;

    return true;
  }

  BookingContactInfo copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
  }) {
    return BookingContactInfo(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  @override
  List<Object?> get props => [fullName, email, phoneNumber];
}
