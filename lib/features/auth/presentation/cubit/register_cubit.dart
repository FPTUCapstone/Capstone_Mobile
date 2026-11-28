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
            'Email này đã được sử dụng. Vui lòng đăng nhập hoặc dùng email khác.',
          AuthIdentityFailure.network =>
            'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối mạng và thử lại.',
          _ => 'Đăng ký thất bại. Vui lòng thử lại sau.',
        }),
      );
    } catch (_) {
      emit(const RegisterFailure('Đăng ký thất bại. Vui lòng thử lại sau.'));
    }
  }
}
