import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/fetch_operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/resubmit_operator_application.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/resubmit_operator_application_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/services/operator_document_picker.dart';

void main() {
  late _MockRepository repository;
  late _MockPicker picker;
  late OperatorApplicationCubit operatorCubit;
  late AuthSessionCubit sessionCubit;

  final defaultRejectedApplication = OperatorApplication(
    userId: 1,
    userStatus: 'Rejected',
    approvalStatus: 'Rejected',
    companyName: 'Đà Nẵng Travel',
    businessLicenseNo: '48-001/2024/TCDL-GPLHQT',
    taxCode: '0401234567',
    contactPerson: 'Trần Văn A',
    businessAddress: '123 Bạch Đằng, Đà Nẵng',
    contactPhone: '0901234567',
    rejectionReason: 'Incorrect document provided',
    resubmissionCount: 1,
    documents: [
      OperatorApplicationDocument(
        documentId: 101,
        documentType: 'BusinessLicense',
        status: 'Rejected',
        uploadedAtUtc: DateTime.utc(2026, 3, 1),
      ),
    ],
  );

  setUp(() async {
    repository = _MockRepository();
    picker = _MockPicker();
    repository.applicationToReturn = defaultRejectedApplication;
    operatorCubit = OperatorApplicationCubit(
      FetchOperatorApplication(repository),
      ResubmitOperatorApplicationUseCase(repository),
    );
    sessionCubit = AuthSessionCubit(
      null,
      _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'tourOperator',
        AppConstants.keepSignedInKey: 'true',
        AppConstants.sessionApplicationStatusKey:
            TourOperatorApplicationStatus.rejected.name,
      }),
    );
    await sessionCubit.restoreSession();
  });

  tearDown(() {
    operatorCubit.close();
    sessionCubit.close();
  });

  Future<void> pumpTestApp(
    WidgetTester tester, {
    String initialLocation = AppRoutes.operatorApplicationResubmit,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.operatorApplication,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Operator Application Status Page')),
          ),
        ),
        GoRoute(
          path: AppRoutes.operatorApplicationResubmit,
          builder: (context, state) =>
              ResubmitOperatorApplicationPage(picker: picker),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<OperatorApplicationCubit>.value(value: operatorCubit),
          BlocProvider<AuthSessionCubit>.value(value: sessionCubit),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pre-fills rejected application, displays rejection banner and existing documents',
    (tester) async {
      await pumpTestApp(tester);

      expect(find.text('Nộp lại hồ sơ đối tác'), findsOneWidget);
      expect(find.text('Lý do từ chối'), findsOneWidget);
      expect(find.text('Incorrect document provided'), findsOneWidget);
      expect(find.text('Đà Nẵng Travel'), findsOneWidget);
      expect(find.text('48-001/2024/TCDL-GPLHQT'), findsOneWidget);
      expect(find.text('0401234567'), findsOneWidget);
      expect(find.text('Trần Văn A'), findsOneWidget);
      expect(find.text('123 Bạch Đằng, Đà Nẵng'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);
      expect(find.text('Giấy phép kinh doanh #101'), findsOneWidget);
      expect(
        find.text('Thay giấy phép kinh doanh (không bắt buộc)'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Để trống nếu muốn giữ nguyên bản giấy phép gần nhất để xét duyệt lại.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'submits successfully while retaining existing license (no file uploaded)',
    (tester) async {
      repository.applicationAfterResubmit = OperatorApplication(
        userId: 1,
        userStatus: 'PendingApproval',
        approvalStatus: 'PendingApproval',
        companyName: 'Đà Nẵng Travel',
        businessLicenseNo: '48-001/2024/TCDL-GPLHQT',
        taxCode: '0401234567',
        contactPerson: 'Trần Văn A',
        resubmissionCount: 2,
        documents: const [],
      );

      await pumpTestApp(tester);

      final submitBtn = find.text('Nộp lại hồ sơ');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(repository.resubmitCallCount, 1);
      expect(repository.lastResubmitInput?.businessLicenseDocument, isNull);
      expect(
        sessionCubit.state.applicationStatus,
        TourOperatorApplicationStatus.pendingApproval,
      );
      expect(find.text('Operator Application Status Page'), findsOneWidget);
    },
  );

  testWidgets(
    'submits successfully with a replacement business licence document',
    (tester) async {
      repository.applicationAfterResubmit = OperatorApplication(
        userId: 1,
        userStatus: 'PendingApproval',
        approvalStatus: 'PendingApproval',
        companyName: 'Đà Nẵng Travel',
        businessLicenseNo: '48-001/2024/TCDL-GPLHQT',
        taxCode: '0401234567',
        contactPerson: 'Trần Văn A',
        resubmissionCount: 2,
        documents: const [],
      );

      picker.filesToReturn = [
        OperatorDocumentUpload(
          fileName: 'new_license.pdf',
          contentType: 'application/pdf',
          bytes: Uint8List.fromList([37, 80, 68, 70]),
        ),
      ];

      await pumpTestApp(tester);

      final replaceBtn = find.text(
        'Thay giấy phép kinh doanh (không bắt buộc)',
      );
      await tester.ensureVisible(replaceBtn);
      await tester.tap(replaceBtn);
      await tester.pumpAndSettle();

      expect(picker.pickCallCount, 1);
      expect(find.text('new_license.pdf'), findsOneWidget);

      final submitBtn = find.text('Nộp lại hồ sơ');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(repository.resubmitCallCount, 1);
      expect(
        repository.lastResubmitInput?.businessLicenseDocument?.fileName,
        'new_license.pdf',
      );
      expect(find.text('Operator Application Status Page'), findsOneWidget);
    },
  );

  testWidgets(
    'requires business licence document when application has no existing license',
    (tester) async {
      repository.applicationToReturn = OperatorApplication(
        userId: 1,
        userStatus: 'Rejected',
        approvalStatus: 'Rejected',
        companyName: 'Đà Nẵng Travel',
        businessLicenseNo: '48-001/2024/TCDL-GPLHQT',
        taxCode: '0401234567',
        contactPerson: 'Trần Văn A',
        resubmissionCount: 1,
        documents: const [],
      );

      await pumpTestApp(tester);

      expect(
        find.text('Tải lên giấy phép kinh doanh (bắt buộc)'),
        findsOneWidget,
      );
      expect(
        find.text('Cần tải lên giấy phép kinh doanh để nộp lại hồ sơ.'),
        findsOneWidget,
      );

      final submitBtn = find.text('Nộp lại hồ sơ');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Vui lòng tải lên bản sao giấy phép kinh doanh.'),
        findsOneWidget,
      );
      expect(repository.resubmitCallCount, 0);
    },
  );

  testWidgets(
    'performs client-side validation on empty required fields and invalid formats',
    (tester) async {
      await pumpTestApp(tester);

      final companyField = find.widgetWithText(TextField, 'Đà Nẵng Travel');
      await tester.enterText(companyField, '');

      final taxField = find.widgetWithText(TextField, '0401234567');
      await tester.enterText(taxField, '123');

      final licenceField = find.widgetWithText(
        TextField,
        '48-001/2024/TCDL-GPLHQT',
      );
      await tester.enterText(licenceField, 'invalid-code');

      final phoneField = find.widgetWithText(TextField, '0901234567');
      await tester.enterText(phoneField, '12345');

      final submitBtn = find.text('Nộp lại hồ sơ');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập thông tin này.'), findsOneWidget);
      expect(
        find.text(
          'Mã số thuế phải gồm 10 chữ số, hoặc 10 chữ số kèm dấu gạch ngang và 3 chữ số chi nhánh.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Vui lòng nhập số giấy phép lữ hành nội địa hoặc quốc tế hợp lệ.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Số điện thoại phải gồm 10 chữ số và bắt đầu bằng số 0.'),
        findsOneWidget,
      );
      expect(repository.resubmitCallCount, 0);
    },
  );

  testWidgets(
    'displays error alert when document picker throws OperatorDocumentReadFailure',
    (tester) async {
      picker.failureToThrow = const OperatorDocumentReadFailure();

      await pumpTestApp(tester);

      final replaceBtn = find.text(
        'Thay giấy phép kinh doanh (không bắt buộc)',
      );
      await tester.ensureVisible(replaceBtn);
      await tester.tap(replaceBtn);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Định dạng tệp không được hỗ trợ hoặc vượt quá dung lượng cho phép.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('uploads supporting documents and reflects count in UI', (
    tester,
  ) async {
    repository.applicationAfterResubmit = OperatorApplication(
      userId: 1,
      userStatus: 'PendingApproval',
      approvalStatus: 'PendingApproval',
      companyName: 'Đà Nẵng Travel',
      businessLicenseNo: '48-001/2024/TCDL-GPLHQT',
      taxCode: '0401234567',
      contactPerson: 'Trần Văn A',
      resubmissionCount: 2,
      documents: const [],
    );

    picker.filesToReturn = [
      OperatorDocumentUpload(
        fileName: 'doc1.pdf',
        contentType: 'application/pdf',
        bytes: Uint8List.fromList([1]),
      ),
      OperatorDocumentUpload(
        fileName: 'doc2.pdf',
        contentType: 'application/pdf',
        bytes: Uint8List.fromList([2]),
      ),
    ];

    await pumpTestApp(tester);

    final addSupportingBtn = find.text('Thêm tài liệu bổ sung (tối đa 5 tệp)');
    await tester.ensureVisible(addSupportingBtn);
    await tester.tap(addSupportingBtn);
    await tester.pumpAndSettle();

    expect(find.text('Đã chọn 2 tài liệu bổ sung'), findsOneWidget);

    final submitBtn = find.text('Nộp lại hồ sơ');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(repository.resubmitCallCount, 1);
    expect(repository.lastResubmitInput?.supportingDocuments.length, 2);
  });

  testWidgets(
    'redirects away from resubmit page when loaded application is not rejected',
    (tester) async {
      repository.applicationToReturn = OperatorApplication(
        userId: 1,
        userStatus: 'PendingApproval',
        approvalStatus: 'PendingApproval',
        companyName: 'Đà Nẵng Travel',
        businessLicenseNo: '48-001/2024/TCDL-GPLHQT',
        taxCode: '0401234567',
        contactPerson: 'Trần Văn A',
        resubmissionCount: 1,
        documents: const [],
      );

      await pumpTestApp(tester);

      expect(find.text('Operator Application Status Page'), findsOneWidget);
      expect(find.text('Nộp lại hồ sơ đối tác'), findsNothing);
    },
  );

  testWidgets(
    'displays backend conflict error (MSG159) inline on conflicting field',
    (tester) async {
      repository.failureToThrowOnResubmit = const OperatorApplicationFailure(
        'MSG159',
        fieldErrors: {'taxCode': 'MSG159'},
      );

      await pumpTestApp(tester);

      final submitBtn = find.text('Nộp lại hồ sơ');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Mã số thuế này đã được đăng ký.'), findsOneWidget);
      expect(
        find.text(
          'Số giấy phép kinh doanh hoặc mã số thuế này đã được đăng ký.',
        ),
        findsOneWidget,
      );
    },
  );
}

final class _MockRepository implements OperatorApplicationRepository {
  OperatorApplication? applicationToReturn;
  OperatorApplication? applicationAfterResubmit;
  OperatorApplicationFailure? failureToThrowOnFetch;
  OperatorApplicationFailure? failureToThrowOnResubmit;
  ResubmitOperatorApplication? lastResubmitInput;
  int resubmitCallCount = 0;

  @override
  Future<OperatorApplication> fetchApplication() async {
    if (failureToThrowOnFetch != null) throw failureToThrowOnFetch!;
    if (resubmitCallCount > 0 && applicationAfterResubmit != null) {
      return applicationAfterResubmit!;
    }
    return applicationToReturn!;
  }

  @override
  Future<void> resubmitApplication(ResubmitOperatorApplication input) async {
    resubmitCallCount++;
    lastResubmitInput = input;
    if (failureToThrowOnResubmit != null) throw failureToThrowOnResubmit!;
  }
}

final class _MockPicker implements OperatorDocumentPicker {
  List<OperatorDocumentUpload>? filesToReturn;
  OperatorDocumentReadFailure? failureToThrow;
  int pickCallCount = 0;

  @override
  Future<List<OperatorDocumentUpload>?> pick({required bool multiple}) async {
    pickCallCount++;
    if (failureToThrow != null) throw failureToThrow!;
    return filesToReturn;
  }
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
