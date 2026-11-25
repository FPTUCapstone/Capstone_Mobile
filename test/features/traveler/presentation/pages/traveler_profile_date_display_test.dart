import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/traveler_profile_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/traveler_profile_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_profile_page.dart';

class _Repository implements TravelerProfileRepository {
  static const profile = TravelerProfile(
    fullName: 'Traveler',
    email: 'traveler@example.com',
    phoneNumber: '0901234567',
    dateOfBirth: '2000-01-02',
  );
  String? savedBirth;

  @override
  Future<TravelerProfile> load() async => profile;

  @override
  Future<TravelerProfile> save({
    required String fullName,
    required String phoneNumber,
    String? dateOfBirth,
    Uint8List? avatar,
    String? avatarName,
    String? avatarMime,
  }) async {
    savedBirth = dateOfBirth;
    return profile;
  }
}

void main() {
  testWidgets('displays padded birth date while saving the unchanged ISO day', (
    tester,
  ) async {
    final repository = _Repository();
    serviceLocator.registerFactory<TravelerProfileCubit>(
      () => TravelerProfileCubit(repository),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await serviceLocator.unregister<TravelerProfileCubit>();
    });
    await tester.pumpWidget(const MaterialApp(home: TravelerProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('02/01/2000'), findsOneWidget);
    expect(find.text('2000-01-02'), findsNothing);
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repository.savedBirth, '2000-01-02');

    // Wait for the save snackbar to stop covering the bottom action.
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved name');

    await tester.ensureVisible(find.text('Discard changes'));
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('02/01/2000'), findsOneWidget);
    expect(find.text('Traveler'), findsOneWidget);
    expect(find.text('Unsaved name'), findsNothing);
  });
}
