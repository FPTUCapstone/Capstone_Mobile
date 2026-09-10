abstract final class Validators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? requiredField(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredField(value, fieldName: 'Email');
    if (requiredError != null) {
      return requiredError;
    }
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = requiredField(value, fieldName: 'Password');
    if (requiredError != null) {
      return requiredError;
    }
    if (value!.length < 8 || value.length > 72) {
      return 'Password must be between 8 and 72 characters.';
    }
    if (value.startsWith(' ') || value.endsWith(' ')) {
      return 'Password cannot start or end with a space.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Password must contain uppercase, lowercase, number, and special character.';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (!RegExp(r'^0\d{9}$').hasMatch(value.trim())) {
      return 'Phone number must be 10 digits starting with 0.';
    }
    return null;
  }

  static String? fullName(String? value) {
    final requiredError = requiredField(value, fieldName: 'Full name');
    if (requiredError != null) {
      return requiredError;
    }
    final normalized = value!.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2 || normalized.length > 150) {
      return 'Full name must be between 2 and 150 characters.';
    }
    if (!RegExp(r'^[\p{L}\p{Zs}]+$', unicode: true).hasMatch(normalized)) {
      return 'Full name can only contain letters and spaces.';
    }
    return null;
  }
}
