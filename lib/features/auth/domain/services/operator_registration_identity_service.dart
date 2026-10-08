final class OperatorCreatedIdentity {
  const OperatorCreatedIdentity({required this.userId, required this.idToken});

  final String userId;
  final String idToken;
}

/// Firebase created an account but could not supply a token; recover that UID.
final class OperatorIdentityCreationUncertain implements Exception {
  const OperatorIdentityCreationUncertain(this.userId);

  final String userId;
}

final class OperatorRegistrationIdentityMismatch implements Exception {
  const OperatorRegistrationIdentityMismatch();
}

/// Feature-specific identity operations; the existing Traveler identity API stays unchanged.
abstract interface class OperatorRegistrationIdentityService {
  Future<OperatorCreatedIdentity> create({
    required String email,
    required String password,
  });

  /// The adapter must verify the current user still has [userId] before deletion.
  Future<void> deleteNewlyCreated(String userId);

  /// Signs in the existing Firebase account; this never creates a new user.
  Future<OperatorCreatedIdentity> recover({
    required String email,
    required String password,
  });

  /// Returns null until the matching Firebase account is email verified.
  Future<String?> verifiedIdTokenFor(String email);

  /// Never sends a verification email for a different signed-in account.
  Future<void> sendVerificationEmailFor(String userId, Uri continueUrl);
}
