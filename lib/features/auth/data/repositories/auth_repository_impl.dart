import 'package:trip_mate_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<RegisterTravelerResponse> registerTraveler(
    RegisterTravelerRequest request,
    String firebaseIdToken,
  ) {
    return _remoteDataSource.registerTraveler(request, firebaseIdToken);
  }

  @override
  Future<SessionResponseDto> verifyEmail(String firebaseIdToken) {
    return _remoteDataSource.verifyEmail(firebaseIdToken);
  }

  @override
  Future<SessionResponseDto> googleAuth(String firebaseIdToken) {
    return _remoteDataSource.googleAuth(firebaseIdToken);
  }

  @override
  Future<SessionResponseDto> login(
    LoginRequest request, [
    String? firebaseIdToken,
  ]) {
    return _remoteDataSource.login(request, firebaseIdToken);
  }
}
