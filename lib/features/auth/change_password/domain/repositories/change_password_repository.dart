import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';

abstract interface class ChangePasswordRepository {
  /// Returns the replacement session (new access + refresh token) on
  /// success. Throws a [Failure] (see core/error/failures.dart) on any
  /// rejection; no local secure-storage mutation happens in this layer —
  /// the caller (ChangePasswordCubit) persists the replacement session only
  /// after this call returns successfully.
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
