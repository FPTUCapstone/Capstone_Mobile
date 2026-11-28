import 'package:trip_mate_mobile/core/utils/validators.dart';

/// Contact rules for UC27. Name and phone follow the Profile form; booking
/// requires a phone number and permits an optional, well-formed email.
abstract final class BookingContactValidation {
  static String? fullName(String value) {
    if (value.trim().isEmpty) return 'Vui lòng nhập họ và tên.';
    if (value.trim().length > 100) return 'Tối đa 100 ký tự.';
    return null;
  }

  static String? phone(String value) =>
      Validators.requiredField(value, fieldName: 'số điện thoại') ??
      Validators.phone(value);

  static String? email(String value) =>
      value.trim().isEmpty ? null : Validators.email(value);
}
