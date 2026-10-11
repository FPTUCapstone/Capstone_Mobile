import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';

void main() {
  late _Auth auth;
  late FirebaseOperatorRegistrationIdentityService service;

  setUp(() {
    auth = _Auth();
    service = FirebaseOperatorRegistrationIdentityService(auth);
  });

  test('create returns token from the newly created Firebase user', () async {
    final created = await service.create(
      email: 'operator@example.com',
      password: 'Password123!',
    );
    expect(created.userId, 'operator-uid');
    expect(created.idToken, 'id-token');
    expect(auth.createCalls, 1);
  });

  test('create without token exposes UID for same-account recovery', () async {
    auth.user.tokenUnavailable = true;
    await expectLater(
      service.create(email: 'operator@example.com', password: 'Password123!'),
      throwsA(
        isA<OperatorIdentityCreationUncertain>().having(
          (error) => error.userId,
          'userId',
          'operator-uid',
        ),
      ),
    );
    expect(auth.createCalls, 1);
  });

  test(
    'recovery signs in existing user and rejects a different email',
    () async {
      final recovered = await service.recover(
        email: 'operator@example.com',
        password: 'Password123!',
      );
      expect(recovered.userId, 'operator-uid');
      expect(auth.signInCalls, 1);
      expect(auth.createCalls, 0);

      await expectLater(
        service.recover(email: 'another@example.com', password: 'Password123!'),
        throwsA(isA<OperatorRegistrationIdentityMismatch>()),
      );
    },
  );

  test('deletion and email send refuse a different current UID', () async {
    await expectLater(
      service.deleteNewlyCreated('different-uid'),
      throwsA(isA<OperatorRegistrationIdentityMismatch>()),
    );
    await expectLater(
      service.sendVerificationEmailFor(
        'different-uid',
        Uri.parse('https://tripmate.example/verify-email?flow=operator'),
      ),
      throwsA(isA<OperatorRegistrationIdentityMismatch>()),
    );
    expect(auth.user.deleted, isFalse);
    expect(auth.user.emailSent, isFalse);
  });

  test('email send uses the configured Web continuation URL', () async {
    final url = Uri.parse(
      'https://tripmate.example/verify-email?flow=operator',
    );
    await service.sendVerificationEmailFor('operator-uid', url);
    expect(auth.user.emailSent, isTrue);
    expect(auth.user.actionCodeSettings?.url, url.toString());
  });

  test('verified token reloads matching user and forces refresh', () async {
    expect(await service.verifiedIdTokenFor('operator@example.com'), isNull);
    auth.user.verified = true;
    expect(
      await service.verifiedIdTokenFor('operator@example.com'),
      'fresh-token',
    );
    expect(auth.user.reloadCalls, 2);
    expect(auth.user.forcedTokenCalls, 1);
    await expectLater(
      service.verifiedIdTokenFor('other@example.com'),
      throwsA(isA<OperatorRegistrationIdentityMismatch>()),
    );
    auth.user.uidAfterReload = 'switched-uid';
    await expectLater(
      service.verifiedIdTokenFor('operator@example.com'),
      throwsA(isA<OperatorRegistrationIdentityMismatch>()),
    );
  });
}

final class _Auth extends Fake implements FirebaseAuth {
  final user = _User();
  int createCalls = 0;
  int signInCalls = 0;

  @override
  User? get currentUser => user;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createCalls++;
    return _Credential(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return _Credential(user);
  }
}

final class _Credential extends Fake implements UserCredential {
  _Credential(this._user);
  final User _user;

  @override
  User? get user => _user;
}

final class _User extends Fake implements User {
  bool verified = false;
  bool deleted = false;
  bool emailSent = false;
  ActionCodeSettings? actionCodeSettings;
  int reloadCalls = 0;
  int forcedTokenCalls = 0;
  bool tokenUnavailable = false;
  String? uidAfterReload;
  String uidValue = 'operator-uid';

  @override
  String get uid => uidValue;

  @override
  String? get email => 'operator@example.com';

  @override
  bool get emailVerified => verified;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) forcedTokenCalls++;
    if (tokenUnavailable) return null;
    return forceRefresh ? 'fresh-token' : 'id-token';
  }

  @override
  Future<void> reload() async {
    reloadCalls++;
    if (uidAfterReload != null) uidValue = uidAfterReload!;
  }

  @override
  Future<void> delete() async {
    deleted = true;
  }

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    emailSent = true;
    this.actionCodeSettings = actionCodeSettings;
  }
}
