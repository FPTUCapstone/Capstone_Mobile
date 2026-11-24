import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/operator_onboarding_state.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/operator_contracts/data/models/operator_contract_dto.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/entities/operator_contract.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/repositories/operator_contract_repository.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/cubit/operator_contract_cubit.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/pages/operator_contract_page.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/widgets/contract_signature_pad.dart';
import 'operator_contract_dto_test.dart' show contractPayload;

AuthSessionCubit _session() {
  final session = AuthSessionCubit();
  // Seed a real final Cubit for this isolated page test, without substituting authentication behavior.
  // ignore: invalid_use_of_protected_member
  session.emit(
    const AuthSessionState.authenticated(
      UserRole.tourOperator,
      applicationStatus: TourOperatorApplicationStatus.approved,
      onboardingState: OperatorOnboardingState.active,
    ),
  );
  return session;
}

class _Repository implements OperatorContractRepository {
  _Repository(this.value);
  final OperatorContract value;
  @override
  Future<OperatorContract?> current() async => value;
  @override
  Future<Uint8List> document(OperatorContract contract) async =>
      Uint8List.fromList('%PDF-test'.codeUnits);
  @override
  Future<void> renewSession() async {}
  @override
  Future<OperatorContract> prepare(
    OperatorContract contract, {
    required String signerName,
    required String signerTitle,
    required String signerCapacity,
  }) async => value;
  @override
  Future<ContractSigningChallenge> requestChallenge(
    OperatorContract contract,
  ) async => throw UnimplementedError();
  @override
  Future<OperatorContract> sign(
    OperatorContract contract,
    ContractSignatureSubmission submission,
  ) async => throw UnimplementedError();
}

void main() {
  Future<void> open(WidgetTester tester, OperatorContract contract) async {
    final session = _session(),
        cubit = OperatorContractCubit(_Repository(contract));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
      await session.close();
    });
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthSessionCubit>.value(value: session),
          BlocProvider<OperatorContractCubit>.value(value: cubit),
        ],
        child: MaterialApp(
          home: OperatorContractPage(
            pdfBuilder: (bytes, onOpened, onFailure) => TextButton(
              onPressed: onOpened,
              child: const Text('PDF đã được tải đúng bản'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('consent stays disabled until private PDF is actually opened', (
    tester,
  ) async {
    await open(
      tester,
      OperatorContractDto.fromJson(contractPayload()).toDomain(),
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    await tester.tap(find.text('Mở và kiểm tra PDF hợp đồng'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    await tester.ensureVisible(find.text('PDF đã được tải đúng bản'));
    await tester.tap(find.text('PDF đã được tải đúng bản'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNotNull,
    );
  });
  testWidgets(
    'signed contract is read only and existing Active session can stay to read it',
    (tester) async {
      await open(
        tester,
        OperatorContractDto.fromJson(
          contractPayload(status: 'Signed'),
        ).toDomain(),
      );
      expect(find.text('Đã ký hợp đồng'), findsOneWidget);
      expect(find.byType(ContractSignaturePad), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Cập nhật phiên đăng nhập'), findsNothing);
    },
  );
}
