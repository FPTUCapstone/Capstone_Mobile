abstract interface class PasswordRecoveryRepository {
  Future<void> requestPasswordReset(String email);

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
