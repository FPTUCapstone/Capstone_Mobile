import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';

abstract interface class AuthRepository {
  Future<RegisterTravelerResponse> registerTraveler(
    RegisterTravelerRequest request,
    String firebaseIdToken,
  );

  Future<SessionResponseDto> verifyEmail(String firebaseIdToken);

  Future<SessionResponseDto> googleAuth(String firebaseIdToken);

  Future<SessionResponseDto> login(
    LoginRequest request, [
    String? firebaseIdToken,
  ]);
}
