import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_auth_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_state.dart';

final class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._authRepository, this._firebaseAuthService)
    : super(const RegisterInitial());

  final AuthRepository _authRepository;
  final FirebaseAuthService _firebaseAuthService;

  Future<void> registerTraveler({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    required bool acceptedTerms,
    String? phone,
  }) async {
    emit(const RegisterLoading());
    try {
      final sanitizedEmail = email.trim().toLowerCase();
      final sanitizedPhone = (phone != null && phone.trim().isNotEmpty)
          ? phone.trim()
          : null;

      final request = RegisterTravelerRequest(
        fullName: fullName.trim(),
        email: sanitizedEmail,
        password: password,
        acceptedTerms: acceptedTerms,
        phoneNumber: sanitizedPhone,
      );

      final firebaseIdToken = await _firebaseAuthService.registerWithEmail(
        email: sanitizedEmail,
        password: password,
      );
      final response = await _authRepository.registerTraveler(
        request,
        firebaseIdToken,
      );
      await _firebaseAuthService.sendEmailVerification();
      emit(RegisterSuccess(response));
    } on AppException catch (e) {
      emit(RegisterFailure(e.message));
    } on FirebaseAuthException catch (e) {
      emit(
        RegisterFailure(switch (e.code) {
          'email-already-in-use' =>
            'An account with this email already exists. Please sign in or use another email.',
          'network-request-failed' =>
            'TripMate is temporarily unable to process your request. Please check your connection and try again.',
          _ => 'Registration failed. Please try again later.',
        }),
      );
    } catch (_) {
      emit(
        const RegisterFailure('Registration failed. Please try again later.'),
      );
    }
  }
}
