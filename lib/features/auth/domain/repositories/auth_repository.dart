import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';

abstract interface class AuthRepository {
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration registration,
    String firebaseIdToken,
  );

  Future<AuthSession> verifyEmail(String firebaseIdToken);

  Future<AuthSession> googleAuth(String firebaseIdToken);

  Future<AuthSession> login(
    AuthCredentials credentials, [
    String? firebaseIdToken,
  ]);

  Future<void> logout(String? refreshToken);
}
