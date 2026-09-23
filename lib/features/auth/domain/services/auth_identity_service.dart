enum AuthIdentityFailure {
  invalidCredentials,
  emailAlreadyInUse,
  network,
  tooManyRequests,
  noCurrentUser,
  canceled,
  unavailable,
  unknown,
}

final class AuthIdentityException implements Exception {
  const AuthIdentityException(this.failure);

  final AuthIdentityFailure failure;
}

abstract interface class AuthIdentityService {
  Future<String?> get currentUserEmail;

  Future<String> registerWithEmail({
    required String email,
    required String password,
  });

  Future<String> signInWithGoogle();

  Future<void> sendEmailVerification();

  Future<String?> refreshIdToken();

  Future<bool> get isEmailVerified;

  Future<void> signOut();
}
