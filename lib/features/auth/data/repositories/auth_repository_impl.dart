import 'package:trip_mate_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/data/mappers/auth_mapper.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration registration,
    String firebaseIdToken,
  ) async {
    final response = await _remoteDataSource.registerTraveler(
      registration.toDto(),
      firebaseIdToken,
    );
    return response.toDomain();
  }

  @override
  Future<AuthSession> verifyEmail(String firebaseIdToken) async {
    final response = await _remoteDataSource.verifyEmail(firebaseIdToken);
    return response.toDomain();
  }

  @override
  Future<AuthSession> googleAuth(String firebaseIdToken) async {
    final response = await _remoteDataSource.googleAuth(firebaseIdToken);
    return response.toDomain();
  }

  @override
  Future<AuthSession> login(
    AuthCredentials credentials, [
    String? firebaseIdToken,
  ]) async {
    final response = await _remoteDataSource.login(
      credentials.toDto(),
      firebaseIdToken,
    );
    return response.toDomain();
  }
}
