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

    expect(find.text('1. Tài khoản'), findsOneWidget);
    expect(find.text('Tên doanh nghiệp'), findsNothing);
    expect(find.text('Chọn giấy phép kinh doanh'), findsNothing);
    expect(find.text('Resend email for an existing account'), findsNothing);
    expect(find.text('Tôi đã xác minh email'), findsNothing);
    await enter(tester, 'Địa chỉ email', 'owner@example.com');
    await enter(tester, 'Mật khẩu', 'Secure123!');
    await enter(tester, 'Xác nhận mật khẩu', 'Secure123!');
    await tester.ensureVisible(find.text('Tiếp theo'));
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();

    expect(find.text('2. Doanh nghiệp'), findsOneWidget);
    expect(find.text('Địa chỉ email'), findsNothing);
    expect(find.text('Chọn giấy phép kinh doanh'), findsNothing);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('1. Tài khoản'), findsOneWidget);
    expect(cubit.state.values['email'], 'owner@example.com');
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vietnamese company details survive step navigation', (
    tester,
  ) async {
    await pumpPage(tester);
    await enter(tester, 'Địa chỉ email', 'owner@example.com');
    await enter(tester, 'Mật khẩu', 'Secure123!');
    await enter(tester, 'Xác nhận mật khẩu', 'Secure123!');
    await tester.ensureVisible(find.text('Tiếp theo'));
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();

    const company = 'Công ty Du lịch Đà Nẵng';
    const contact = 'Nguyễn Thị Ánh';
    const address = '123 đường Trần Phú, Đà Nẵng';
    await enter(tester, 'Tên doanh nghiệp', company);
    await enter(
      tester,
      'Số giấy phép kinh doanh lữ hành',
      '79-0123/2026/TCDL-GPLHQT',
    );
    await enter(tester, 'Mã số thuế', '1234567890');
    await enter(tester, 'Người liên hệ', contact);
    await enter(tester, 'Địa chỉ kinh doanh (không bắt buộc)', address);
    await tester.ensureVisible(find.text('Tiếp theo'));
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay lại'));
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
    await enter(tester, 'Địa chỉ email', 'owner@example.com');
    await enter(tester, 'Mật khẩu', 'Secure123!');
    await enter(tester, 'Xác nhận mật khẩu', 'Secure123!');
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();

    final companyField = find.widgetWithText(TextFormField, 'Tên doanh nghiệp');
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
    await enter(tester, 'Địa chỉ email', 'owner@example.com');
    await enter(tester, 'Mật khẩu', 'Secure123!');
    await enter(tester, 'Xác nhận mật khẩu', 'Secure123!');
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp theo'));
    await tester.pump();
    expect(cubit.state.errors['companyName'], isNotNull);

    final companyField = find.widgetWithText(TextFormField, 'Tên doanh nghiệp');
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
    await enter(tester, 'Địa chỉ email', 'owner@example.com');
    await enter(tester, 'Mật khẩu', 'Secure123!');
    await enter(tester, 'Xác nhận mật khẩu', 'Secure123!');
    await tester.ensureVisible(find.text('Tiếp theo'));
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();

    await enter(tester, 'Tên doanh nghiệp', 'TripMate Tours');
    await enter(
      tester,
      'Số giấy phép kinh doanh lữ hành',
      '79-0123/2026/TCDL-GPLHQT',
    );
    await enter(tester, 'Mã số thuế', '1234567890');
    await enter(tester, 'Người liên hệ', 'Operator Owner');
    await tester.ensureVisible(find.text('Tiếp theo'));
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();

    expect(find.text('3. Hồ sơ pháp lý'), findsOneWidget);
    expect(find.text('Tên doanh nghiệp'), findsNothing);
    await tester.ensureVisible(find.text('Chọn giấy phép kinh doanh'));
    await tester.tap(find.text('Chọn giấy phép kinh doanh'));
    await tester.pumpAndSettle();
    expect(find.text('licence.pdf'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Chọn tài liệu bổ sung (không bắt buộc, tối đa 5 tệp)'),
    );
    await tester.tap(
      find.text('Chọn tài liệu bổ sung (không bắt buộc, tối đa 5 tệp)'),
    );
    await tester.pumpAndSettle();
    expect(picker.calls, [false, true]);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Xác minh email trước'));
    await tester.tap(find.text('Xác minh email trước'));
    await tester.pumpAndSettle();

    expect(repository.posts, 0);
    expect(find.text('Hồ sơ chưa được gửi'), findsOneWidget);
    expect(find.text('Kiểm tra hộp thư của bạn'), findsOneWidget);
    expect(find.text('o***@example.com'), findsOneWidget);
    expect(find.text('Gửi lại email xác minh'), findsOneWidget);
    expect(find.text('Tôi đã xác minh email — Gửi hồ sơ'), findsOneWidget);
    expect(find.text('Mock selection'), findsNothing);

    await tester.tap(find.text('Gửi lại email xác minh'));
    await tester.pump();
    expect(identity.sentEmails, 2);
    expect(find.text('Gửi lại sau 60s'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    identity.verified = true;
    await tester.tap(find.text('Tôi đã xác minh email — Gửi hồ sơ'));
    await tester.pumpAndSettle();
    expect(repository.posts, 1);
    expect(find.text('Đã gửi hồ sơ đăng ký'), findsOneWidget);
    expect(find.text('Chờ phê duyệt'), findsOneWidget);
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
    expect(find.text('Hồ sơ chưa được gửi'), findsOneWidget);

    identity.verified = true;
    await tester.tap(find.text('Tôi đã xác minh email — Gửi hồ sơ'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi hồ sơ đăng ký'), findsOneWidget);
    expect(find.text('Kiểm tra hộp thư của bạn'), findsNothing);
    expect(find.text('Chờ phê duyệt'), findsOneWidget);
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
