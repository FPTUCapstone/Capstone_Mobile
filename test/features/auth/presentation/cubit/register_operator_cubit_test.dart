import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/register_tour_operator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_operator_cubit.dart';

void main() {
  late _Repository repository;
  late _Identity identity;
  late RegisterOperatorCubit cubit;

  setUp(() {
    repository = _Repository();
    identity = _Identity();
    cubit = RegisterOperatorCubit(
      RegisterTourOperator(
        repository: repository,
        identityService: identity,
        verificationContinueUrl: () =>
            Uri.parse('https://tripmate.example/verify-email?flow=operator'),
      ),
    );
  });
  tearDown(() => cubit.close());

  test(
    'validates each step and preserves values and files across navigation',
    () {
      expect(cubit.next(), isFalse);
      expect(cubit.state.step, 0);
      expect(cubit.state.errors['email'], isNotNull);

      _fillAccount(cubit);
      expect(cubit.next(), isTrue);
      expect(cubit.state.step, 1);
      expect(cubit.next(), isFalse);
      expect(cubit.state.errors['contactPerson'], isNotNull);

      _fillCompany(cubit);
      expect(cubit.next(), isTrue);
      cubit.setBusinessLicence(_licence);
      cubit.setSupportingDocuments([_licence]);
      cubit.setAcceptedTerms(true);
      cubit.back();
      cubit.back();
      expect(cubit.state.values['email'], 'owner@example.com');
      expect(cubit.next(), isTrue);
      expect(cubit.next(), isTrue);
      expect(cubit.state.businessLicence?.fileName, 'licence.pdf');
      expect(cubit.state.supportingDocuments, hasLength(1));
      expect(cubit.state.acceptedTerms, isTrue);
    },
  );

  test('company step blocks malformed identifiers with field feedback', () {
    _fillAccount(cubit);
    expect(cubit.next(), isTrue);
    _fillCompany(cubit);
    cubit.updateField('taxCode', 'TAX-1');
    cubit.updateField('businessLicenseNo', 'LIC-1');
    expect(cubit.next(), isFalse);
    expect(cubit.state.step, 1);
    expect(cubit.state.errors['taxCode'], contains('10 digits'));
    expect(
      cubit.state.errors['businessLicenseNo'],
      contains('Travel Licence Number'),
    );
    expect(identity.creates, 0);
  });

  test(
    'blocks missing licence and terms without calling external services',
    () async {
      _fillAllText(cubit);
      expect(cubit.next(), isTrue);
      expect(cubit.next(), isTrue);
      await cubit.submit();
      expect(cubit.state.errors['businessLicenseDocument'], isNotNull);
      expect(cubit.state.errors['acceptTerms'], isNotNull);
      expect(identity.creates, 0);
      expect(repository.posts, 0);
    },
  );

  test('one in-flight application POST after email verification', () async {
    _fillReady(cubit);
    await cubit.submit();
    expect(cubit.state.phase, RegisterOperatorPhase.awaitingVerification);
    expect(repository.posts, 0);
    identity.verified = true;
    repository.pending = Completer<TourOperatorRegistrationResult>();
    final first = cubit.confirmVerifiedEmail();
    await Future<void>.delayed(Duration.zero);
    final second = cubit.confirmVerifiedEmail();
    expect(cubit.state.isBusy, isTrue);
    expect(repository.posts, 1);
    repository.pending!.complete(
      const TourOperatorRegistrationResult(
        userId: 42,
        applicationStatus: 'PendingApproval',
        messageCode: 'MSG08',
      ),
    );
    await Future.wait([first, second]);
    expect(cubit.state.phase, RegisterOperatorPhase.submitted);
    expect(cubit.state.outcome?.registration.userId, 42);
    expect(identity.creates, 1);
    expect(repository.posts, 1);
  });

  test(
    'verified existing account can resume without another verification email',
    () async {
      _fillReady(cubit);
      cubit.setResumeExistingIdentity(true);
      identity.verified = true;
      await cubit.submit();
      expect(cubit.state.phase, RegisterOperatorPhase.awaitingVerification);
      expect(cubit.state.alreadyVerified, isTrue);
      expect(repository.posts, 0);
      await cubit.confirmVerifiedEmail();
      expect(cubit.state.phase, RegisterOperatorPhase.submitted);
      expect(repository.posts, 1);
      expect(identity.creates, 0);
    },
  );

  test(
    'unknown outcome offers explicit same-identity retry, never claims success',
    () async {
      _fillReady(cubit);
      repository.failure = const OperatorRegistrationUncertain();
      await cubit.submit();
      identity.verified = true;
      await cubit.confirmVerifiedEmail();
      expect(cubit.state.phase, RegisterOperatorPhase.uncertain);
      expect(cubit.state.outcome, isNull);
      expect(identity.creates, 1);
      repository.failure = null;
      await cubit.retryUnknownOutcome();
      expect(cubit.state.phase, RegisterOperatorPhase.submitted);
      expect(identity.creates, 1);
      expect(identity.recovers, 1);
      expect(repository.posts, 2);
    },
  );

  test('email failure can resend before the first POST', () async {
    _fillReady(cubit);
    identity.failEmailOnce = true;
    await cubit.submit();
    expect(cubit.state.phase, RegisterOperatorPhase.awaitingVerification);
    expect(cubit.state.emailSent, isFalse);
    await cubit.resendEmail();
    expect(cubit.state.emailSent, isTrue);
    expect(repository.posts, 0);
    identity.verified = true;
    await cubit.confirmVerifiedEmail();
    expect(cubit.state.phase, RegisterOperatorPhase.submitted);
    expect(repository.posts, 1);
    expect(repository.confirmations, 1);
  });

  test(
    'a definite 400 on existing-identity retry stays editable with inline error',
    () async {
      _fillReady(cubit);
      repository.failure = const OperatorRegistrationRejected(
        'MSG158',
        fieldErrors: {
          'businessLicenseDocument': ['Use PDF, JPG or PNG, up to 5 MB.'],
        },
      );
      cubit.setResumeExistingIdentity(true);
      await cubit.submit();
      identity.verified = true;
      await cubit.confirmVerifiedEmail();
      expect(cubit.state.phase, RegisterOperatorPhase.editing);
      expect(cubit.state.step, 2);
      expect(cubit.state.errors['businessLicenseDocument'], isNotNull);
      expect(cubit.state.outcome, isNull);
      cubit.setBusinessLicence(_licence);
      expect(cubit.state.errors['businessLicenseDocument'], isNull);
    },
  );

  test(
    'a definite 409 on existing-identity retry is not reported as success',
    () async {
      _fillReady(cubit);
      repository.failure = const OperatorRegistrationRejected('MSG160');
      cubit.setResumeExistingIdentity(true);
      await cubit.submit();
      identity.verified = true;
      await cubit.confirmVerifiedEmail();
      expect(cubit.state.phase, RegisterOperatorPhase.editing);
      expect(cubit.state.outcome, isNull);
      expect(cubit.state.canRetryOriginal, isFalse);
      expect(identity.creates, 0);
      expect(identity.recovers, 1);
    },
  );

  test('409 after an actual unknown POST outcome remains uncertain', () async {
    _fillReady(cubit);
    repository.failure = const OperatorRegistrationUncertain();
    await cubit.submit();
    identity.verified = true;
    await cubit.confirmVerifiedEmail();
    repository.failure = const OperatorRegistrationRejected('MSG160');
    await cubit.retryUnknownOutcome();
    expect(cubit.state.phase, RegisterOperatorPhase.uncertain);
    expect(cubit.state.outcome, isNull);
    expect(cubit.state.canRetryOriginal, isTrue);
    expect(cubit.state.notice, contains('already pending review'));
    expect(cubit.state.notice, contains('earlier request'));
  });

  test(
    'business identifier conflict remains visible after uncertain retry',
    () async {
      _fillReady(cubit);
      repository.failure = const OperatorRegistrationUncertain();
      await cubit.submit();
      identity.verified = true;
      await cubit.confirmVerifiedEmail();
      repository.failure = const OperatorRegistrationRejected('MSG159');

      await cubit.retryUnknownOutcome();

      expect(cubit.state.phase, RegisterOperatorPhase.uncertain);
      expect(cubit.state.outcome, isNull);
      expect(
        cubit.state.notice,
        contains('business licence number or tax code is already registered'),
      );
      expect(cubit.state.notice, contains('earlier request'));
    },
  );

  test(
    'failed resend or unverified email never sends an application',
    () async {
      _fillReady(cubit);
      await cubit.submit();
      identity.failEmailOnce = true;
      await cubit.resendEmail();
      expect(cubit.state.phase, RegisterOperatorPhase.awaitingVerification);
      expect(cubit.state.outcome, isNull);
      await cubit.confirmVerifiedEmail();
      expect(cubit.state.phase, RegisterOperatorPhase.awaitingVerification);
      expect(repository.posts, 0);
    },
  );
}

void _fillAccount(RegisterOperatorCubit cubit) {
  cubit.updateField('email', 'owner@example.com');
  cubit.updateField('password', 'Secure123!');
  cubit.updateField('confirmPassword', 'Secure123!');
}

void _fillCompany(RegisterOperatorCubit cubit) {
  cubit.updateField('companyName', 'TripMate Tours');
  cubit.updateField('businessLicenseNo', '79-0123/2026/TCDL-GPLHQT');
  cubit.updateField('taxCode', '1234567890');
  cubit.updateField('contactPerson', 'Operator Owner');
}

void _fillAllText(RegisterOperatorCubit cubit) {
  _fillAccount(cubit);
  _fillCompany(cubit);
}

void _fillReady(RegisterOperatorCubit cubit) {
  _fillAllText(cubit);
  cubit.next();
  cubit.next();
  cubit.setBusinessLicence(_licence);
  cubit.setAcceptedTerms(true);
}

final _licence = OperatorDocumentUpload(
  fileName: 'licence.pdf',
  contentType: 'application/pdf',
  bytes: Uint8List.fromList([37, 80, 68, 70]),
);

final class _Repository implements TourOperatorRegistrationRepository {
  int posts = 0;
  int confirmations = 0;
  Completer<TourOperatorRegistrationResult>? pending;
  Object? failure;

  @override
  Future<TourOperatorRegistrationResult> register(
    TourOperatorRegistration registration,
    String firebaseIdToken,
  ) async {
    posts++;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return const TourOperatorRegistrationResult(
      userId: 42,
      applicationStatus: 'PendingApproval',
      messageCode: 'MSG08',
    );
  }

  @override
  Future<void> confirmVerifiedEmail(String firebaseIdToken) async {
    confirmations++;
  }
}

final class _Identity implements OperatorRegistrationIdentityService {
  int creates = 0;
  int recovers = 0;
  bool failEmailOnce = false;
  bool verified = false;

  @override
  Future<OperatorCreatedIdentity> create({
    required String email,
    required String password,
  }) async {
    creates++;
    return const OperatorCreatedIdentity(userId: 'uid-42', idToken: 'token');
  }

  @override
  Future<OperatorCreatedIdentity> recover({
    required String email,
    required String password,
  }) async {
    recovers++;
    return const OperatorCreatedIdentity(userId: 'uid-42', idToken: 'token');
  }

  @override
  Future<void> deleteNewlyCreated(String userId) async {}

  @override
  Future<void> sendVerificationEmailFor(String userId, Uri continueUrl) async {
    if (failEmailOnce) {
      failEmailOnce = false;
      throw StateError('mail');
    }
  }

  @override
  Future<String?> verifiedIdTokenFor(String email) async =>
      verified ? 'verified-token' : null;
}
