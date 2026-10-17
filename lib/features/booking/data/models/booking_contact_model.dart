import 'package:trip_mate_mobile/features/booking/domain/entities/booking_contact.dart';

/// API model for GET /api/v1/traveler/profile, limited to the values UC-27
/// needs to initialize the editable lead-traveler contact fields.
final class BookingContactModel {
  const BookingContactModel({
    required this.fullName,
    this.phoneNumber,
    this.email,
  });

  factory BookingContactModel.fromJson(Object? payload) {
    if (payload is! Map) {
      throw const FormatException('Traveler profile must be an object.');
    }
    final json = Map<String, Object?>.from(payload);
    final fullName = json['fullName'];
    if (fullName is! String || fullName.trim().isEmpty) {
      throw const FormatException('Traveler profile fullName is missing.');
    }
    return BookingContactModel(
      fullName: fullName.trim(),
      phoneNumber: _optionalString(json['phoneNumber']),
      email: _optionalString(json['email']),
    );
  }

  final String fullName;
  final String? phoneNumber;
  final String? email;

  BookingContact toDomain() => BookingContact(
    fullName: fullName,
    phoneNumber: phoneNumber,
    email: email,
  );

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Traveler profile contact field is invalid.');
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
