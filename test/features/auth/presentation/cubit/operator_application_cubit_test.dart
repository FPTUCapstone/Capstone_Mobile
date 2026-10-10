import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_document_upload.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/operator_application_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/fetch_operator_application.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/resubmit_operator_application.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';

final class _MockRepository implements OperatorApplicationRepository {
  OperatorApplication? applicationToReturn;
  OperatorApplicationFailure? failureToThrow;
  OperatorApplicationFailure? resubmitFailureToThrow;
  ResubmitOperatorApplication? lastResubmitInput;

  @override
  Future<OperatorApplication> fetchApplication() async {
    if (failureToThrow != null) throw failureToThrow!;
    return applicationToReturn ??
        OperatorApplication(
          userId: 1,
          userStatus: 'Rejected',
          approvalStatus: 'Rejected',
          companyName: 'Trip Co',
          businessLicenseNo: '1234567890',
          taxCode: '0123456789',
          contactPerson: 'Manager',
          resubmissionCount: 1,
          documents: const [],
        );
  }

  @override
  Future<void> resubmitApplication(ResubmitOperatorApplication input) async {
    lastResubmitInput = input;
    if (resubmitFailureToThrow != null) throw resubmitFailureToThrow!;
    if (failureToThrow != null) throw failureToThrow!;
  }
}

void main() {
  late _MockRepository repository;
  late OperatorApplicationCubit cubit;

  setUp(() async {
    repository = _MockRepository();
    cubit = OperatorApplicationCubit(
      FetchOperatorApplication(repository),
      ResubmitOperatorApplicationUseCase(repository),
    );
    await cubit.loadApplication();
  });

  tearDown(() => cubit.close());

  const testInput = ResubmitOperatorApplication(
    companyName: 'Trip Co',
    businessLicenseNo: '1234567890',
    taxCode: '0123456789',
    contactPerson: 'Manager',
    supportingDocuments: [],
  );

  test('maps taxCode MSG159 error to specific inline field message', () async {
    repository.failureToThrow = const OperatorApplicationFailure(
      'MSG159',
      fieldErrors: {'taxCode': 'MSG159'},
    );

    final result = await cubit.resubmit(testInput);

    expect(result, isFalse);
    expect(
      cubit.state.errorMessage,
      'This business licence number or tax code is already registered.',
    );
    expect(
      cubit.state.fieldErrors['taxCode'],
      'This tax code is already registered.',
    );
    expect(cubit.state.fieldErrors['businessLicenseNo'], isNull);
  });

  test(
    'maps businessLicenseNo MSG159 error to specific inline field message',
    () async {
      repository.failureToThrow = const OperatorApplicationFailure(
        'MSG159',
        fieldErrors: {'businessLicenseNo': 'MSG159'},
      );

      final result = await cubit.resubmit(testInput);

      expect(result, isFalse);
      expect(
        cubit.state.errorMessage,
        'This business licence number or tax code is already registered.',
      );
      expect(
        cubit.state.fieldErrors['businessLicenseNo'],
        'This business licence number is already registered.',
      );
      expect(cubit.state.fieldErrors['taxCode'], isNull);
    },
  );

  test('maps both identifier errors when both conflict', () async {
    repository.failureToThrow = const OperatorApplicationFailure(
      'MSG159',
      fieldErrors: {'taxCode': 'MSG159', 'businessLicenseNo': 'MSG159'},
    );

    final result = await cubit.resubmit(testInput);

    expect(result, isFalse);
    expect(
      cubit.state.fieldErrors['taxCode'],
      'This tax code is already registered.',
    );
    expect(
      cubit.state.fieldErrors['businessLicenseNo'],
      'This business licence number is already registered.',
    );
  });

  test(
    'resubmit success flow keeps existing license when document is null',
    () async {
      repository.applicationToReturn = OperatorApplication(
        userId: 1,
        userStatus: 'PendingApproval',
        approvalStatus: 'PendingApproval',
        companyName: 'Trip Co',
        businessLicenseNo: '1234567890',
        taxCode: '0123456789',
        contactPerson: 'Manager',
        resubmissionCount: 2,
        documents: const [],
      );

      final result = await cubit.resubmit(testInput);

      expect(result, isTrue);
      expect(repository.lastResubmitInput?.businessLicenseDocument, isNull);
      expect(cubit.state.status, OperatorApplicationStatus.pending);
      expect(
        cubit.state.successMessage,
        'Application resubmitted successfully. It is now pending administrator review.',
      );
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.fieldErrors, isEmpty);
    },
  );

  test(
    'resubmit success flow passes replacement document when provided',
    () async {
      final doc = OperatorDocumentUpload(
        fileName: 'new_license.pdf',
        contentType: 'application/pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      repository.applicationToReturn = OperatorApplication(
        userId: 1,
        userStatus: 'PendingApproval',
        approvalStatus: 'PendingApproval',
        companyName: 'Trip Co',
        businessLicenseNo: '1234567890',
        taxCode: '0123456789',
        contactPerson: 'Manager',
        resubmissionCount: 2,
        documents: const [],
      );

      final result = await cubit.resubmit(
        ResubmitOperatorApplication(
          companyName: 'Trip Co',
          businessLicenseNo: '1234567890',
          taxCode: '0123456789',
          contactPerson: 'Manager',
          businessLicenseDocument: doc,
          supportingDocuments: const [],
        ),
      );

      expect(result, isTrue);
      expect(
        repository.lastResubmitInput?.businessLicenseDocument?.fileName,
        'new_license.pdf',
      );
      expect(cubit.state.status, OperatorApplicationStatus.pending);
    },
  );

  test(
    'reloads application when repository throws MSG161 (concurrency / no longer rejected)',
    () async {
      repository.resubmitFailureToThrow = const OperatorApplicationFailure(
        'MSG161',
      );
      repository.applicationToReturn = OperatorApplication(
        userId: 1,
        userStatus: 'PendingApproval',
        approvalStatus: 'PendingApproval',
        companyName: 'Trip Co',
        businessLicenseNo: '1234567890',
        taxCode: '0123456789',
        contactPerson: 'Manager',
        resubmissionCount: 1,
        documents: const [],
      );

      final result = await cubit.resubmit(testInput);

      expect(result, isFalse);
      expect(cubit.state.status, OperatorApplicationStatus.pending);
    },
  );

  test(
    'prevents resubmission when application is not in rejected status',
    () async {
      repository.applicationToReturn = OperatorApplication(
        userId: 1,
        userStatus: 'PendingApproval',
        approvalStatus: 'PendingApproval',
        companyName: 'Trip Co',
        businessLicenseNo: '1234567890',
        taxCode: '0123456789',
        contactPerson: 'Manager',
        resubmissionCount: 1,
        documents: const [],
      );
      await cubit.loadApplication();
      expect(cubit.state.status, OperatorApplicationStatus.pending);

      final result = await cubit.resubmit(testInput);

      expect(result, isFalse);
      expect(repository.lastResubmitInput, isNull);
    },
  );
}
