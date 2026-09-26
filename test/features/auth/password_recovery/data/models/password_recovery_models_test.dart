import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/confirm_password_reset_request.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/password_reset_message_dto.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/password_reset_request.dart';

void main() {
  group('password recovery transport models', () {
    test('request serializes only email', () {
      const request = PasswordResetRequest(email: 'user@example.com');

      expect(request.toJson(), {'email': 'user@example.com'});
    });

    test('confirm preserves leading zero and excludes confirmPassword', () {
      const request = ConfirmPasswordResetRequest(
        email: 'user@example.com',
        code: '012345',
        newPassword: 'NewPassword123!',
      );

      expect(request.toJson(), {
        'email': 'user@example.com',
        'code': '012345',
        'newPassword': 'NewPassword123!',
      });
      expect(request.toJson(), isNot(contains('confirmPassword')));
    });

    test('success parses a direct message DTO', () {
      final response = PasswordResetMessageDto.fromJson(const {
        'message': 'Request accepted.',
      });

      expect(response.message, 'Request accepted.');
    });

    test('success rejects missing or blank message', () {
      expect(
        () => PasswordResetMessageDto.fromJson(const {}),
        throwsFormatException,
      );
      expect(
        () => PasswordResetMessageDto.fromJson(const {'message': '  '}),
        throwsFormatException,
      );
    });
  });
}
