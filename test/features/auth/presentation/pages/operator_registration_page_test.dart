import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/register_tour_operator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_operator_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_registration_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/services/operator_document_picker.dart';

void main() {
  late RegisterOperatorCubit cubit;
  late _Repository repository;
  late _Picker picker;
  late _Identity identity;

  setUp(() {
    repository = _Repository();
    picker = _Picker();
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

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<RegisterOperatorCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: OperatorRegistrationPage(documentPicker: picker),
        ),
      ),
    );
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.scrollUntilVisible(
      field,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field, value);
    await tester.pump();
  }

  testWidgets('wizard renders one step at a time and retains account values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);

    expect(find.text('1. Account'), findsOneWidget);
    expect(find.text('Company name'), findsNothing);
    expect(find.text('Choose business licence'), findsNothing);
    expect(find.text('Resend email for an existing account'), findsNothing);
    expect(find.text("I've verified my email"), findsNothing);
    await enter(tester, 'Email address', 'owner@example.com');
    await enter(tester, 'Password', 'Secure123!');
    await enter(tester, 'Confirm password', 'Secure123!');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('2. Company'), findsOneWidget);
    expect(find.text('Email address'), findsNothing);
    expect(find.text('Choose business licence'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1. Account'), findsOneWidget);
    expect(cubit.state.values['email'], 'owner@example.com');
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vietnamese company details survive step navigation', (
    tester,
  ) async {
    await pumpPage(tester);
    await enter(tester, 'Email address', 'owner@example.com');
    await enter(tester, 'Password', 'Secure123!');
    await enter(tester, 'Confirm password', 'Secure123!');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    const company = 'Công ty Du lịch Đà Nẵng';
    const contact = 'Nguyễn Thị Ánh';
    const address = '123 đường Trần Phú, Đà Nẵng';
    await enter(tester, 'Company name', company);
    await enter(tester, 'Business licence number', '79-0123/2026/TCDL-GPLHQT');
    await enter(tester, 'Tax code', '1234567890');
    await enter(tester, 'Contact person', contact);
    await enter(tester, 'Business address (optional)', address);
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(cubit.state.values['companyName'], company);
    expect(cubit.state.values['contactPerson'], contact);
    expect(cubit.state.values['businessAddress'], address);
    expect(find.text(company), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(address),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(address), findsOneWidget);
  });

  testWidgets('Vietnamese composing text remains in the company field', (
    tester,
  ) async {
    await pumpPage(tester);
    await enter(tester, 'Email address', 'owner@example.com');
    await enter(tester, 'Password', 'Secure123!');
    await enter(tester, 'Confirm password', 'Secure123!');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final companyField = find.widgetWithText(TextFormField, 'Company name');
    await tester.showKeyboard(companyField);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Công',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 1, end: 4),
      ),
    );
    await tester.pump();

    expect(cubit.state.values['companyName'], isNull);
    expect(
      tester.widget<TextFormField>(companyField).controller!.value.composing,
      const TextRange(start: 1, end: 4),
    );

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Công ty Đà Nẵng',
        selection: TextSelection.collapsed(offset: 15),
      ),
    );
    await tester.pump();
    expect(cubit.state.values['companyName'], 'Công ty Đà Nẵng');
  });

  testWidgets('Vietnamese IME keeps composing text after a validation error', (
    tester,
  ) async {
    await pumpPage(tester);
    await enter(tester, 'Email address', 'owner@example.com');
    await enter(tester, 'Password', 'Secure123!');
    await enter(tester, 'Confirm password', 'Secure123!');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(cubit.state.errors['companyName'], isNotNull);

    final companyField = find.widgetWithText(TextFormField, 'Company name');
    await tester.showKeyboard(companyField);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Nguyễ',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
    );
    await tester.pump();

    expect(cubit.state.errors['companyName'], isNotNull);
    expect(
      tester.widget<TextFormField>(companyField).controller!.text,
      'Nguyễ',
    );
    expect(
      tester.widget<TextFormField>(companyField).controller!.value.composing,
      const TextRange(start: 0, end: 5),
    );

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Nguyễn Văn',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );
    await tester.pump();
    expect(cubit.state.values['companyName'], 'Nguyễn Văn');
    expect(cubit.state.errors['companyName'], isNull);
  });

  testWidgets('email verification precedes the first application POST', (
    tester,
  ) async {
    await pumpPage(tester);
    await enter(tester, 'Email address', 'owner@example.com');
    await enter(tester, 'Password', 'Secure123!');
    await enter(tester, 'Confirm password', 'Secure123!');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await enter(tester, 'Company name', 'TripMate Tours');
    await enter(tester, 'Business licence number', '79-0123/2026/TCDL-GPLHQT');
    await enter(tester, 'Tax code', '1234567890');
    await enter(tester, 'Contact person', 'Operator Owner');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('3. Documents and terms'), findsOneWidget);
    expect(find.text('Company name'), findsNothing);
    await tester.ensureVisible(find.text('Choose business licence'));
    await tester.tap(find.text('Choose business licence'));
    await tester.pumpAndSettle();
    expect(find.text('licence.pdf'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Choose supporting documents (optional, up to 5)'),
    );
    await tester.tap(
      find.text('Choose supporting documents (optional, up to 5)'),
    );
    await tester.pumpAndSettle();
    expect(picker.calls, [false, true]);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Verify email first'));
    await tester.tap(find.text('Verify email first'));
    await tester.pumpAndSettle();

    expect(repository.posts, 0);
    expect(find.text('Application not submitted yet'), findsOneWidget);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('o***@example.com'), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(
      find.text('I verified my email — submit application'),
      findsOneWidget,
    );
    expect(find.text('Mock selection'), findsNothing);

    await tester.tap(find.text('Resend verification email'));
    await tester.pump();
    expect(identity.sentEmails, 2);
    expect(find.text('Resend in 60s'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    identity.verified = true;
    await tester.tap(find.text('I verified my email — submit application'));
    await tester.pumpAndSettle();
    expect(repository.posts, 1);
    expect(find.text('Application submitted'), findsOneWidget);
    expect(find.text('Pending Approval'), findsOneWidget);
  });

  testWidgets('verified submit removes stale email instruction and warning', (
    tester,
  ) async {
    identity.failEmailOnce = true;
    cubit.updateField('email', 'owner@example.com');
    cubit.updateField('password', 'Secure123!');
    cubit.updateField('confirmPassword', 'Secure123!');
    expect(cubit.next(), isTrue);
    cubit.updateField('companyName', 'TripMate Tours');
    cubit.updateField('businessLicenseNo', '79-0123/2026/TCDL-GPLHQT');
    cubit.updateField('taxCode', '1234567890');
    cubit.updateField('contactPerson', 'Operator Owner');
    expect(cubit.next(), isTrue);
    cubit.setBusinessLicence(_licence);
    cubit.setAcceptedTerms(true);
    await cubit.submit();
    expect(cubit.state.emailSent, isFalse);
    await pumpPage(tester);
    expect(find.text('Application not submitted yet'), findsOneWidget);

    identity.verified = true;
    await tester.tap(find.text('I verified my email — submit application'));
    await tester.pumpAndSettle();

    expect(find.text('Application submitted'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
    expect(find.text('Pending Approval'), findsOneWidget);
    expect(repository.posts, 1);
  });
}

final class _Picker implements OperatorDocumentPicker {
  final calls = <bool>[];
  @override
  Future<List<OperatorDocumentUpload>?> pick({required bool multiple}) async {
    calls.add(multiple);
    return multiple ? [_licence] : [_licence];
  }
}

final _licence = OperatorDocumentUpload(
  fileName: 'licence.pdf',
  contentType: 'application/pdf',
  bytes: Uint8List.fromList([37, 80, 68, 70]),
);

final class _Repository implements TourOperatorRegistrationRepository {
  int posts = 0;
  @override
  Future<TourOperatorRegistrationResult> register(
    TourOperatorRegistration registration,
    String firebaseIdToken,
  ) async {
    posts++;
    return const TourOperatorRegistrationResult(
      userId: 42,
      applicationStatus: 'PendingApproval',
      messageCode: 'MSG08',
    );
  }

  @override
  Future<void> confirmVerifiedEmail(String firebaseIdToken) async {}
}

final class _Identity implements OperatorRegistrationIdentityService {
  bool failEmailOnce = false;
  bool verified = false;
  int sentEmails = 0;
  @override
  Future<OperatorCreatedIdentity> create({
    required String email,
    required String password,
  }) async => const OperatorCreatedIdentity(userId: 'uid-42', idToken: 'token');
  @override
  Future<OperatorCreatedIdentity> recover({
    required String email,
    required String password,
  }) async => const OperatorCreatedIdentity(userId: 'uid-42', idToken: 'token');
  @override
  Future<void> deleteNewlyCreated(String userId) async {}
  @override
  Future<void> sendVerificationEmailFor(String userId, Uri continueUrl) async {
    sentEmails++;
    if (failEmailOnce) {
      failEmailOnce = false;
      throw StateError('delivery');
    }
  }

  @override
  Future<String?> verifiedIdTokenFor(String email) async =>
      verified ? 'verified-token' : null;
}
