import 'package:firebase_auth/firebase_auth.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';

final class UnavailableOperatorRegistrationIdentityService
    implements OperatorRegistrationIdentityService {
  const UnavailableOperatorRegistrationIdentityService();

  Future<T> _unavailable<T>() => Future<T>.error(
    const AuthIdentityException(AuthIdentityFailure.unavailable),
  );

  @override
  Future<OperatorCreatedIdentity> create({
    required String email,
    required String password,
  }) => _unavailable();

  @override
  Future<OperatorCreatedIdentity> recover({
    required String email,
    required String password,
  }) => _unavailable();

  @override
  Future<void> deleteNewlyCreated(String userId) => _unavailable();

  @override
  Future<void> sendVerificationEmailFor(String userId, Uri continueUrl) =>
      _unavailable();

  @override
  Future<String?> verifiedIdTokenFor(String email) => _unavailable();
}

/// Uses the application's existing FirebaseAuth instance, never a second app.
final class FirebaseOperatorRegistrationIdentityService
    implements OperatorRegistrationIdentityService {
  const FirebaseOperatorRegistrationIdentityService(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<OperatorCreatedIdentity> create({
    required String email,
    required String password,
  }) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _translate(error);
    }
    final user = credential.user;
    if (user == null) {
      throw const AuthIdentityException(AuthIdentityFailure.unknown);
    }
    try {
      return OperatorCreatedIdentity(
        userId: user.uid,
        idToken: _requiredToken(await user.getIdToken()),
      );
    } catch (_) {
      // Creation succeeded. Never retry create while this Firebase UID exists.
      throw OperatorIdentityCreationUncertain(user.uid);
    }
  }

  @override
  Future<OperatorCreatedIdentity> recover({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null ||
          _auth.currentUser?.uid != user.uid ||
          !_sameEmail(user.email, email)) {
        throw const OperatorRegistrationIdentityMismatch();
      }
      return OperatorCreatedIdentity(
        userId: user.uid,
        idToken: _requiredToken(await user.getIdToken(true)),
      );
    } on FirebaseAuthException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> deleteNewlyCreated(String userId) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      throw const OperatorRegistrationIdentityMismatch();
    }
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> sendVerificationEmailFor(String userId, Uri continueUrl) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      throw const OperatorRegistrationIdentityMismatch();
    }
    try {
      await user.sendEmailVerification(
        ActionCodeSettings(url: continueUrl.toString(), handleCodeInApp: false),
      );
    } on FirebaseAuthException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<String?> verifiedIdTokenFor(String email) async {
    final initialUser = _auth.currentUser;
    if (initialUser == null || !_sameEmail(initialUser.email, email)) {
      throw const OperatorRegistrationIdentityMismatch();
    }
    final originalUid = initialUser.uid;
    try {
      await initialUser.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null ||
          refreshedUser.uid != originalUid ||
          !_sameEmail(refreshedUser.email, email)) {
        throw const OperatorRegistrationIdentityMismatch();
      }
      if (!refreshedUser.emailVerified) return null;
      return _requiredToken(await refreshedUser.getIdToken(true));
    } on FirebaseAuthException catch (error) {
      throw _translate(error);
    }
  }

  bool _sameEmail(String? actual, String expected) =>
      actual?.trim().toLowerCase() == expected.trim().toLowerCase();

  String _requiredToken(String? token) {
    if (token == null || token.isEmpty) {
      throw const AuthIdentityException(AuthIdentityFailure.unknown);
    }
    return token;
  }

  AuthIdentityException _translate(FirebaseAuthException error) =>
      AuthIdentityException(switch (error.code) {
        'invalid-email' ||
        'invalid-credential' ||
        'wrong-password' => AuthIdentityFailure.invalidCredentials,
        'email-already-in-use' => AuthIdentityFailure.emailAlreadyInUse,
        'network-request-failed' => AuthIdentityFailure.network,
        'too-many-requests' => AuthIdentityFailure.tooManyRequests,
        'no-current-user' => AuthIdentityFailure.noCurrentUser,
        _ => AuthIdentityFailure.unknown,
      });
}
