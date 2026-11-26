import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_profile_repository.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/usecases/operator_profile_use_cases.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/cubit/operator_profile_cubit.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_profile_edit_page.dart';

final class _FakeRepo implements OperatorProfileRepository {
  _FakeRepo(this.current);

  OperatorProfile current;
  UpdateOperatorProfileInput? lastInput;
  Object? updateError;

  @override
  Future<OperatorProfile> getProfile() async => current;

  @override
  Future<OperatorProfile> updateProfile(
    UpdateOperatorProfileInput input,
  ) async {
    lastInput = input;
    if (updateError != null) throw updateError!;
    current = OperatorProfile(
      userId: current.userId,
      businessName: input.businessName,
      businessDescription: input.businessDescription,
      businessAddress: input.businessAddress,
      contactPhone: input.contactPhone,
      contactEmail: input.contactEmail,
      website: input.website.isEmpty ? null : input.website,
      logoUrl: input.removeLogo ? null : current.logoUrl,
      businessLicenceNumber: current.businessLicenceNumber,
      taxCode: current.taxCode,
      approvalStatus: current.approvalStatus,
      accountEmail: current.accountEmail,
    );
    return current;
  }
}

const _profile = OperatorProfile(
  userId: 12,
  businessName: 'Sun Tours',
  businessDescription: 'Family tours',
  businessAddress: '1 Beach Rd',
  contactPhone: '0901234567',
  contactEmail: 'hello@suntours.vn',
  website: 'https://suntours.vn',
  businessLicenceNumber: '79-1234/2026/TCDL-GPLHQT',
  taxCode: '0312345678',
  approvalStatus: 'Approved',
  accountEmail: 'owner@suntours.vn',
);

void main() {
  testWidgets('falls back to loading profile when initialProfile is null', (
    tester,
  ) async {
    final repo = _FakeRepo(_profile);
    final cubit = OperatorProfileCubit(
      getProfile: GetOperatorProfileUseCase(repo),
      updateProfile: UpdateOperatorProfileUseCase(repo),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const OperatorProfileEditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sun Tours'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('79-1234/2026/TCDL-GPLHQT'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('79-1234/2026/TCDL-GPLHQT'), findsOneWidget);
    expect(find.text('0312345678'), findsOneWidget);
    expect(find.text('owner@suntours.vn'), findsOneWidget);
  });

  testWidgets('renders removeLogo error under logo section', (tester) async {
    final repo = _FakeRepo(_profile)
      ..updateError = const OperatorProfileValidationException(
        OperatorProfileValidationErrors(
          removeLogo: OperatorProfileMessages.invalidRemoveLogo,
        ),
      );
    final cubit = OperatorProfileCubit(
      getProfile: GetOperatorProfileUseCase(repo),
      updateProfile: UpdateOperatorProfileUseCase(repo),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const OperatorProfileEditPage(initialProfile: _profile),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('operator_profile_save_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('operator_profile_save_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('operator_profile_logo_error')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(OperatorProfileMessages.invalidRemoveLogo),
      findsOneWidget,
    );
  });

  testWidgets('pops updated profile on save without showing MSG121', (
    tester,
  ) async {
    final repo = _FakeRepo(_profile);
    final cubit = OperatorProfileCubit(
      getProfile: GetOperatorProfileUseCase(repo),
      updateProfile: UpdateOperatorProfileUseCase(repo),
    );
    OperatorProfile? poppedResult;
    final validPng = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                poppedResult = await context.push<OperatorProfile>('/edit');
              },
              child: const Text('Open Edit'),
            ),
          ),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: OperatorProfileEditPage(
              initialProfile: _profile,
              logoPicker: () async => OperatorLogoUploadData(
                bytes: validPng,
                fileName: 'logo.png',
                mimeType: 'image/png',
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open Edit'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('operator_profile_pick_logo_button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('field_business_name')),
      'Sun Tours Updated',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('operator_profile_save_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('operator_profile_save_button')));
    await tester.pumpAndSettle();

    expect(poppedResult?.businessName, 'Sun Tours Updated');
    expect(repo.lastInput?.logo?.fileName, 'logo.png');
    expect(repo.lastInput?.removeLogo, isFalse);
    expect(find.textContaining('MSG121'), findsNothing);
  });
}
