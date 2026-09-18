import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';

final class UnavailableFirebaseAuthService implements AuthIdentityService {
  const UnavailableFirebaseAuthService();

  @override
  Future<String?> get currentUserEmail async => null;

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) => _unavailable();

  @override
  Future<String> signInWithGoogle() => _unavailable();

  @override
  Future<void> sendEmailVerification() => _unavailable();

  @override
  Future<String?> refreshIdToken() => _unavailable();

  @override
  Future<bool> get isEmailVerified async => false;

  @override
  Future<void> signOut() => _unavailable();

  Future<T> _unavailable<T>() => Future<T>.error(
    const AuthIdentityException(AuthIdentityFailure.unavailable),
  );
}

final class FirebaseAuthServiceImpl implements AuthIdentityService {
  FirebaseAuthServiceImpl(this._firebaseAuth, this._googleSignIn);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  @override
  Future<String?> get currentUserEmail async =>
      _firebaseAuth.currentUser?.email;

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) => _mapProviderErrors(() async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requireToken(await credential.user?.getIdToken());
  });

  @override
  Future<String> signInWithGoogle() => _mapProviderErrors(() async {
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthIdentityException(AuthIdentityFailure.unknown);
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final firebaseCredential = await _firebaseAuth.signInWithCredential(
      credential,
    );
    return _requireToken(await firebaseCredential.user?.getIdToken());
  });

  @override
  Future<void> sendEmailVerification() => _mapProviderErrors(() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthIdentityException(AuthIdentityFailure.noCurrentUser);
    }
    await user.sendEmailVerification();
  });

  @override
  Future<String?> refreshIdToken() => _mapProviderErrors(
    () => _reloadVerifiedUserAndRefreshToken(_firebaseAuth.currentUser),
  );

  Future<String?> _reloadVerifiedUserAndRefreshToken(User? user) async {
    if (user == null) {
      throw const AuthIdentityException(AuthIdentityFailure.noCurrentUser);
    }
    await user.reload();
    final refreshedUser = _firebaseAuth.currentUser;
    final emailVerified = refreshedUser?.emailVerified ?? false;
    if (!emailVerified) return null;
    return _requireToken(await refreshedUser?.getIdToken(true));
  }

  @override
  Future<bool> get isEmailVerified async =>
      _firebaseAuth.currentUser?.emailVerified ?? false;

  @override
  Future<void> signOut() => _mapProviderErrors(() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  });

  String _requireToken(String? token) {
    if (token == null || token.isEmpty) {
      throw const AuthIdentityException(AuthIdentityFailure.unknown);
    }
    return token;
  }

  Future<T> _mapProviderErrors<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthIdentityException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthIdentityException(_firebaseFailure(error.code));
    } on GoogleSignInException catch (error) {
      throw AuthIdentityException(
        error.code == GoogleSignInExceptionCode.canceled
            ? AuthIdentityFailure.canceled
            : AuthIdentityFailure.unknown,
      );
    }
  }

  AuthIdentityFailure _firebaseFailure(String code) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-email' => AuthIdentityFailure.invalidCredentials,
    'email-already-in-use' => AuthIdentityFailure.emailAlreadyInUse,
    'network-request-failed' => AuthIdentityFailure.network,
    'too-many-requests' => AuthIdentityFailure.tooManyRequests,
    'no-current-user' => AuthIdentityFailure.noCurrentUser,
    _ => AuthIdentityFailure.unknown,
  };
}
