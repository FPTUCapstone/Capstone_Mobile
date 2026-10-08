import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/register_tour_operator.dart';

void main() {
  late _Identity identity;
  late _Repository repository;
  late List<String> calls;
  late RegisterTourOperator useCase;

  setUp(() {
    calls = [];
    identity = _Identity(calls);
    repository = _Repository(calls);
    useCase = RegisterTourOperator(
      repository: repository,
      identityService: identity,
      verificationContinueUrl: () => Uri.parse(
        'https://tripmate.example/verify-email?flow=operator-mobile',
      ),
    );
  });

  test('Operator application is not sent before email verification', () async {
    await useCase(validRegistration());
    expect(calls, ['create', 'email']);
    expect(repository.registration, isNull);

    identity.verifiedToken = 'fresh-verified-token';
    final outcome = await useCase.submitVerifiedApplication();
    expect(outcome.registration.userId, 42);
    expect(repository.token, 'fresh-verified-token');
    expect(calls, ['create', 'email', 'verified-token', 'register', 'confirm']);
  });

  test(
    'An interrupted Operator registration reuses the Firebase account',
    () async {
      final start = await useCase.retryWithExistingIdentity(
        validRegistration(),
      );
      expect(start.emailSent, isTrue);
      expect(calls, ['recover', 'verified-token', 'email']);
      expect(repository.registration, isNull);
    },
  );

  test(
    'valid registration creates identity and sends email without posting',
    () async {
      final outcome = await useCase(validRegistration());
      expect(calls, ['create', 'email']);
      expect(repository.registration, isNull);
      expect(identity.continueUrl?.queryParameters['flow'], 'operator-mobile');
      expect(outcome.emailSent, isTrue);
      expect(outcome.alreadyVerified, isFalse);
    },
  );

  test('invalid data fails before any external call', () async {
    final invalid = <TourOperatorRegistration>[
      validRegistration(email: 'bad-email'),
      validRegistration(email: '   '),
      validRegistration(password: '        ', confirmPassword: '        '),
      validRegistration(password: 'Good pass1!'),
      validRegistration(
        password: 'GoodPassword1! ',
        confirmPassword: 'GoodPassword1! ',
      ),
      validRegistration(confirmPassword: 'Different1!'),
      validRegistration(companyName: ' '),
      validRegistration(businessLicenseNo: ' '),
      validRegistration(taxCode: ' '),
      validRegistration(taxCode: 'TAX-1'),
      validRegistration(taxCode: '0315678901001'),
      validRegistration(businessLicenseNo: 'LIC-1'),
      validRegistration(businessLicenseNo: '79-0123/2026/TCDL-GPLHND'),
      validRegistration(contactPerson: ' '),
      validRegistration(companyName: 'x' * 201),
      validRegistration(businessLicenseNo: 'x' * 101),
      validRegistration(taxCode: 'x' * 51),
      validRegistration(contactPerson: 'x' * 151),
      validRegistration(businessAddress: 'x' * 301),
      validRegistration(contactPhone: '12345'),
      validRegistration(acceptedTerms: false),
      validRegistration(businessLicenseDocument: null),
      validRegistration(
        businessLicenseDocument: document('licence.exe', 'application/pdf'),
      ),
      validRegistration(
        businessLicenseDocument: document(
          'licence.pdf',
          'application/pdf',
          Uint8List(5 * 1024 * 1024 + 1),
        ),
      ),
      validRegistration(
        supportingDocuments: List.generate(
          6,
          (index) => document('support$index.pdf', 'application/pdf'),
        ),
      ),
    ];
    for (final registration in invalid) {
      await expectLater(
        useCase(registration),
        throwsA(isA<ValidationFailure>()),
      );
    }
    expect(calls, isEmpty);
  });

  test(
    'branch Tax Code and domestic Travel Licence pass before identity creation',
    () async {
      await useCase(
        validRegistration(
          taxCode: '0315678901-001',
          businessLicenseNo: '01-0456/2025/SDL-GPLHND',
        ),
      );
      expect(calls, ['create', 'email']);
    },
  );

  test(
    'malformed identifiers report field errors before external calls',
    () async {
      await expectLater(
        useCase(
          validRegistration(taxCode: 'TAX-1', businessLicenseNo: 'LIC-1'),
        ),
        throwsA(
          isA<ValidationFailure>()
              .having(
                (failure) => failure.fieldErrors['taxCode']?.single,
                'tax code',
                contains('10 digits'),
              )
              .having(
                (failure) => failure.fieldErrors['businessLicenseNo']?.single,
                'licence',
                contains('Travel Licence Number'),
              ),
        ),
      );
      expect(calls, isEmpty);
    },
  );

  test('missing Web origin fails before Firebase identity creation', () async {
    useCase = RegisterTourOperator(
      repository: repository,
      identityService: identity,
      verificationContinueUrl: () => throw StateError('not configured'),
    );
    await expectLater(
      useCase(validRegistration()),
      throwsA(isA<OperatorVerificationConfigurationFailure>()),
    );
    expect(calls, isEmpty);
  });

  test(
    'definite BE rejection keeps the verified account for correction',
    () async {
      repository.error = const OperatorRegistrationRejected('MSG159');
      await useCase(validRegistration());
      identity.verifiedToken = 'fresh-verified-token';
      await expectLater(
        useCase.submitVerifiedApplication(),
        throwsA(isA<OperatorRegistrationRejected>()),
      );
      expect(calls, ['create', 'email', 'verified-token', 'register']);
      expect(identity.deletedId, isNull);
    },
  );

  test(
    'after a rejection the same identity can submit corrected details',
    () async {
      repository.error = const OperatorRegistrationRejected('MSG159');
      await useCase(validRegistration());
      identity.verifiedToken = 'fresh-verified-token';
      await expectLater(
        useCase.submitVerifiedApplication(),
        throwsA(isA<OperatorRegistrationRejected>()),
      );
      repository.error = null;
      final start = await useCase.retryWithExistingIdentity(
        validRegistration(taxCode: '0201234567'),
      );
      expect(start.alreadyVerified, isTrue);
      await useCase.submitVerifiedApplication();
      expect(repository.registration?.taxCode, '0201234567');
      expect(calls.where((call) => call == 'create'), hasLength(1));
      expect(calls.where((call) => call == 'register'), hasLength(2));
    },
  );

  test('unknown POST outcome retains identity', () async {
    repository.error = const OperatorRegistrationUncertain();
    await useCase(validRegistration());
    identity.verifiedToken = 'fresh-verified-token';
    await expectLater(
      useCase.submitVerifiedApplication(),
      throwsA(isA<OperatorRegistrationUncertain>()),
    );
    expect(calls, ['create', 'email', 'verified-token', 'register']);
    await expectLater(
      useCase(validRegistration()),
      throwsA(isA<OperatorRegistrationRecoveryRequired>()),
    );
    expect(calls, ['create', 'email', 'verified-token', 'register']);
  });

  test(
    'explicit retry reauthenticates same identity and frozen form',
    () async {
      final original = validRegistration(
        businessLicenseDocument: document('licence.pdf', 'application/pdf'),
      );
      repository.error = const OperatorRegistrationUncertain();
      await useCase(original);
      identity.verifiedToken = 'fresh-verified-token';
      await expectLater(
        useCase.submitVerifiedApplication(),
        throwsA(isA<OperatorRegistrationUncertain>()),
      );
      original.businessLicenseDocument!.bytes[0] = 0;
      repository.error = null;
      final outcome = await useCase.retryUnknownOutcome();
      expect(outcome.registration.userId, 42);
      expect(calls, [
        'create',
        'email',
        'verified-token',
        'register',
        'recover',
        'verified-token',
        'register',
        'confirm',
      ]);
      expect(identity.recoveredEmail, 'operator@example.com');
      expect(repository.token, 'fresh-verified-token');
      expect(repository.registration?.businessLicenseDocument?.bytes[0], 37);
    },
  );

  test('retry refuses a different Firebase identity', () async {
    repository.error = const OperatorRegistrationUncertain();
    await useCase(validRegistration());
    identity.verifiedToken = 'fresh-verified-token';
    await expectLater(
      useCase.submitVerifiedApplication(),
      throwsA(isA<OperatorRegistrationUncertain>()),
    );
    identity.recoveredId = 'different-uid';
    repository.error = null;
    await expectLater(
      useCase.retryUnknownOutcome(),
      throwsA(isA<OperatorRegistrationIdentityMismatch>()),
    );
    expect(calls, ['create', 'email', 'verified-token', 'register', 'recover']);
  });

  test(
    'restart recovery uses existing identity and never creates/deletes',
    () async {
      final start = await useCase.retryWithExistingIdentity(
        validRegistration(),
      );
      expect(start.emailSent, isTrue);
      expect(calls, ['recover', 'verified-token', 'email']);
      expect(repository.registration, isNull);
    },
  );

  test(
    '409 after uncertain retry is not treated as success or cleaned up',
    () async {
      repository.error = const OperatorRegistrationUncertain();
      await useCase(validRegistration());
      identity.verifiedToken = 'fresh-verified-token';
      await expectLater(
        useCase.submitVerifiedApplication(),
        throwsA(isA<OperatorRegistrationUncertain>()),
      );
      repository.error = const OperatorRegistrationRejected('MSG160');
      await expectLater(
        useCase.retryUnknownOutcome(),
        throwsA(isA<OperatorRegistrationRejected>()),
      );
      expect(calls, [
        'create',
        'email',
        'verified-token',
        'register',
        'recover',
        'verified-token',
        'register',
      ]);
      await useCase.resendVerificationEmail();
      expect(calls.last, 'email');
    },
  );

  test('after restart reauth may request email without another POST', () async {
    await useCase.sendRecoveryVerificationEmail(
      email: 'operator@example.com',
      password: 'GoodPassword1!',
    );
    expect(calls, ['recover', 'email']);
  });

  test(
    'email failure keeps the account without sending an application',
    () async {
      identity.emailError = StateError('delivery failed');
      final start = await useCase(validRegistration());
      expect(start.emailSent, isFalse);
      expect(calls, ['create', 'email']);
      expect(repository.registration, isNull);
      identity.emailError = null;
      await useCase.resendVerificationEmail();
      expect(calls, ['create', 'email', 'email']);
    },
  );

  test(
    'confirmation requires verified Firebase evidence then BE acknowledgement',
    () async {
      identity.verifiedToken = null;
      await expectLater(
        useCase.confirmVerifiedEmail('operator@example.com'),
        throwsA(isA<OperatorEmailNotVerified>()),
      );
      expect(calls, ['verified-token']);

      identity.verifiedToken = 'fresh-verified-token';
      await useCase.confirmVerifiedEmail('operator@example.com');
      expect(repository.confirmToken, 'fresh-verified-token');
      expect(calls, ['verified-token', 'verified-token', 'confirm']);
    },
  );

  test(
    'after restart confirmation reauthenticates without creating identity',
    () async {
      identity.verifiedToken = 'fresh-verified-token';
      await useCase.confirmVerifiedEmail(
        'operator@example.com',
        password: 'GoodPassword1!',
      );
      expect(calls, ['recover', 'verified-token', 'confirm']);
    },
  );

  test(
    'Firebase create without token is recovered without creating twice',
    () async {
      identity.createError = const OperatorIdentityCreationUncertain('new-uid');
      await expectLater(
        useCase(validRegistration()),
        throwsA(isA<OperatorIdentityCreationUncertain>()),
      );
      identity.createError = null;
      final start = await useCase.retryWithExistingIdentity(
        validRegistration(),
      );
      expect(start.emailSent, isTrue);
      expect(calls, ['create', 'recover', 'verified-token', 'email']);
    },
  );
}

TourOperatorRegistration validRegistration({
  String email = ' operator@example.com ',
  String password = 'GoodPassword1!',
  String confirmPassword = 'GoodPassword1!',
  String companyName = ' TripMate Tours ',
  String businessLicenseNo = '79-0123/2026/TCDL-GPLHQT',
  String taxCode = '0101234567',
  String contactPerson = 'Operator Name',
  String? businessAddress,
  String? contactPhone,
  bool acceptedTerms = true,
  Object? businessLicenseDocument = _defaultDocument,
  List<OperatorDocumentUpload> supportingDocuments = const [],
}) => TourOperatorRegistration(
  email: email,
  password: password,
  confirmPassword: confirmPassword,
  companyName: companyName,
  businessLicenseNo: businessLicenseNo,
  taxCode: taxCode,
  contactPerson: contactPerson,
  businessAddress: businessAddress,
  contactPhone: contactPhone,
  acceptedTerms: acceptedTerms,
  businessLicenseDocument: identical(businessLicenseDocument, _defaultDocument)
      ? document('licence.pdf', 'application/pdf')
      : businessLicenseDocument as OperatorDocumentUpload?,
  supportingDocuments: supportingDocuments,
);

OperatorDocumentUpload document(String name, String mime, [Uint8List? bytes]) =>
    OperatorDocumentUpload(
      fileName: name,
      contentType: mime,
      bytes: bytes ?? Uint8List.fromList([37, 80, 68, 70, 45]),
    );

const _defaultDocument = _DefaultDocument();

final class _DefaultDocument {
  const _DefaultDocument();
}

final class _Identity implements OperatorRegistrationIdentityService {
  _Identity(this.calls);
  final List<String> calls;
  Uri? continueUrl;
  String? deletedId;
  Object? deleteError;
  Object? emailError;
  Object? createError;
  String recoveredId = 'new-uid';
  String? recoveredEmail;
  String? verifiedToken;

  @override
  Future<OperatorCreatedIdentity> create({
    required String email,
    required String password,
  }) async {
    calls.add('create');
    if (createError != null) throw createError!;
    return const OperatorCreatedIdentity(
      userId: 'new-uid',
      idToken: 'firebase-token',
    );
  }

  @override
  Future<void> deleteNewlyCreated(String userId) async {
    calls.add('delete');
    deletedId = userId;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<void> sendVerificationEmailFor(String userId, Uri continueUrl) async {
    calls.add('email');
    this.continueUrl = continueUrl;
    if (emailError != null) throw emailError!;
  }

  @override
  Future<OperatorCreatedIdentity> recover({
    required String email,
    required String password,
  }) async {
    calls.add('recover');
    recoveredEmail = email;
    return OperatorCreatedIdentity(
      userId: recoveredId,
      idToken: 'recovered-token',
    );
  }

  @override
  Future<String?> verifiedIdTokenFor(String email) async {
    calls.add('verified-token');
    return verifiedToken;
  }
}

final class _Repository implements TourOperatorRegistrationRepository {
  _Repository(this.calls);
  final List<String> calls;
  Object? error;
  String? token;
  TourOperatorRegistration? registration;
  String? confirmToken;

  @override
  Future<TourOperatorRegistrationResult> register(
    TourOperatorRegistration registration,
    String firebaseIdToken,
  ) async {
    calls.add('register');
    this.registration = registration;
    token = firebaseIdToken;
    if (error != null) throw error!;
    return const TourOperatorRegistrationResult(
      userId: 42,
      applicationStatus: 'PendingApproval',
      messageCode: 'MSG08',
    );
  }

  @override
  Future<void> confirmVerifiedEmail(String firebaseIdToken) async {
    calls.add('confirm');
    confirmToken = firebaseIdToken;
  }
}
