import 'package:equatable/equatable.dart';

/// Represents a single participant's details for a Tour Booking (UC-27).
final class BookingParticipant extends Equatable {
  const BookingParticipant({
    this.fullName = '',
    this.dateOfBirth = '',
    this.identityDocumentNumber = '',
    this.phoneNumber = '',
  });

  final String fullName;
  final String dateOfBirth;
  final String identityDocumentNumber;
  final String phoneNumber;

  bool get hasEmptyRequiredField =>
      fullName.trim().isEmpty ||
      dateOfBirth.trim().isEmpty ||
      identityDocumentNumber.trim().isEmpty ||
      phoneNumber.trim().isEmpty;

  /// Validates format rules after checking non-empty fields:
  /// - Full Name: at least 2 characters
  /// - Date of Birth: DD/MM/YYYY or YYYY-MM-DD reasonable date
  /// - Identity Document Number: 8-15 alphanumeric characters (CCCD/CMND/Passport)
  /// - Phone Number: 9-15 digits (optional leading +)
  bool get hasValidFormat {
    if (hasEmptyRequiredField) return false;
    final trimmedName = fullName.trim();
    if (trimmedName.length < 2) return false;

    final dobPattern = RegExp(r'^(\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2})$');
    if (!dobPattern.hasMatch(dateOfBirth.trim())) return false;

    final idPattern = RegExp(r'^[A-Za-z0-9]{8,15}$');
    if (!idPattern.hasMatch(identityDocumentNumber.trim())) return false;

    final normalizedPhone = phoneNumber.trim().replaceAll(' ', '');
    final phonePattern = RegExp(r'^\+?\d{9,15}$');
    if (!phonePattern.hasMatch(normalizedPhone)) return false;

    return true;
  }

  BookingParticipant copyWith({
    String? fullName,
    String? dateOfBirth,
    String? identityDocumentNumber,
    String? phoneNumber,
  }) {
    return BookingParticipant(
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      identityDocumentNumber:
          identityDocumentNumber ?? this.identityDocumentNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  @override
  List<Object?> get props => [
    fullName,
    dateOfBirth,
    identityDocumentNumber,
    phoneNumber,
  ];
}
