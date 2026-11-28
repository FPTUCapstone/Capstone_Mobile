abstract final class Validators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? requiredField(
    String? value, {
    String fieldName = 'Trường này',
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredField(value, fieldName: 'email');
    if (requiredError != null) {
      return requiredError;
    }
    final normalized = value!.trim();
    if (normalized.length > 254) {
      return 'Email không được vượt quá 254 ký tự.';
    }
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Vui lòng nhập địa chỉ email hợp lệ.';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = requiredField(value, fieldName: 'mật khẩu');
    if (requiredError != null) {
      return requiredError;
    }
    if (value!.length < 8 || value.length > 72) {
      return 'Mật khẩu phải từ 8 đến 72 ký tự.';
    }
    if (value != value.trim()) {
      return 'Mật khẩu không được có khoảng trắng ở đầu hoặc cuối.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Mật khẩu phải gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt.';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mã xác nhận.';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return 'Vui lòng nhập đúng 6 chữ số.';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (!RegExp(r'^0\d{9}$').hasMatch(value.trim())) {
      return 'Số điện thoại phải gồm 10 chữ số và bắt đầu bằng số 0.';
    }
    return null;
  }

  static String? fullName(String? value) {
    final requiredError = requiredField(value, fieldName: 'họ và tên');
    if (requiredError != null) {
      return requiredError;
    }
    final normalized = value!.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2 || normalized.length > 150) {
      return 'Họ và tên phải từ 2 đến 150 ký tự.';
    }
    if (!RegExp(r'^[\p{L}\p{Zs}]+$', unicode: true).hasMatch(normalized)) {
      return 'Họ và tên chỉ được chứa chữ cái và khoảng trắng.';
    }
    return null;
  }
}
