import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';

abstract interface class FirebaseAuthService {
  Future<String?> get currentUserEmail;

  Future<String> registerWithEmail({
    required String email,
    required String password,
  });

  Future<String> signInWithEmail({
    required String email,
    required String password,
  });

  Future<String> signInWithGoogle();

  Future<void> sendEmailVerification();

  Future<String?> refreshIdToken();

  Future<bool> get isEmailVerified;

  Future<void> signOut();
}

final class UnavailableFirebaseAuthService implements FirebaseAuthService {
  const UnavailableFirebaseAuthService();

  @override
  Future<String?> get currentUserEmail async => null;

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) => _unavailable();

  @override
  Future<String> signInWithEmail({
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
    const AuthenticationException(
      'Firebase Authentication is not initialized for this build.',
    ),
  );
}

final class FirebaseAuthServiceImpl implements FirebaseAuthService {
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
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final token = await credential.user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Firebase did not return an ID token.',
      );
    }
    return token;
  }

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final token = await _reloadVerifiedUserAndRefreshToken(credential.user);
    if (token == null) {
      throw const AuthenticationException(
        'Please verify your email before continuing.',
      );
    }
    return token;
  }

  @override
  Future<String> signInWithGoogle() async {
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final firebaseCredential = await _firebaseAuth.signInWithCredential(
      credential,
    );
    final firebaseIdToken = await firebaseCredential.user?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Firebase did not return an ID token.',
      );
    }
    return firebaseIdToken;
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No Firebase user is signed in.',
      );
    }
    await user.sendEmailVerification();
  }

  @override
  Future<String?> refreshIdToken() async {
    return _reloadVerifiedUserAndRefreshToken(_firebaseAuth.currentUser);
  }

  Future<String?> _reloadVerifiedUserAndRefreshToken(User? user) async {
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No Firebase user is signed in.',
      );
    }
    if (kDebugMode) {
      debugPrint(
        '[AUTH-VERIFY] emailVerified before reload=${user.emailVerified}',
      );
    }
    await user.reload();
    final refreshedUser = _firebaseAuth.currentUser;
    final emailVerified = refreshedUser?.emailVerified ?? false;
    if (kDebugMode) {
      debugPrint('[AUTH-VERIFY] emailVerified after reload=$emailVerified');
    }
    if (!emailVerified) return null;
    if (kDebugMode) {
      debugPrint('[AUTH-VERIFY] token refresh requested=true');
    }
    final token = await refreshedUser?.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Firebase did not return an ID token.',
      );
    }
    return token;
  }

  @override
  Future<bool> get isEmailVerified async =>
      _firebaseAuth.currentUser?.emailVerified ?? false;

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
