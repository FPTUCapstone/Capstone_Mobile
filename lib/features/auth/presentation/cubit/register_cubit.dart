import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_state.dart';

final class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._authRepository, this._firebaseAuthService)
    : super(const RegisterInitial());

  final AuthRepository _authRepository;
  final AuthIdentityService _firebaseAuthService;

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

      final registration = TravelerRegistration(
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
        registration,
        firebaseIdToken,
      );
      await _firebaseAuthService.sendEmailVerification();
      emit(RegisterSuccess(response));
    } on AppException catch (e) {
      emit(RegisterFailure(e.message));
    } on AuthIdentityException catch (error) {
      emit(
        RegisterFailure(switch (error.failure) {
          AuthIdentityFailure.emailAlreadyInUse =>
            'An account with this email already exists. Please sign in or use another email.',
          AuthIdentityFailure.network =>
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
