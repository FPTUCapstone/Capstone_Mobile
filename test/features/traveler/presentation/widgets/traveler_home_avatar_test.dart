import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/traveler_profile_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/traveler_profile_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/traveler_home_dashboard_view.dart';

import '../cubit/my_trips_cubit_test.dart';

class _ProfileRepository implements TravelerProfileRepository {
  TravelerProfile profile = const TravelerProfile(
    fullName: 'Nguyễn Văn Linh',
    email: 'test@example.com',
  );
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
  }) => throw UnimplementedError();
}

void main() {
  late _ProfileRepository repository;
  late MyTripsCubit trips;
  setUp(() async {
    await serviceLocator.reset();
    repository = _ProfileRepository();
    trips = MyTripsCubit(repository: FakeItineraryListRepository({}));
    serviceLocator.registerFactory<TravelerProfileCubit>(
      () => TravelerProfileCubit(repository),
    );
  });
  tearDown(() async {
    await trips.close();
    await serviceLocator.reset();
  });

  Future<void> mount(WidgetTester tester, {bool active = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: trips,
            child: TravelerHomeDashboardView(isActive: active),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses the profile avatar and reloads it when returning Home', (
    tester,
  ) async {
    repository.profile = const TravelerProfile(
      fullName: 'Nguyễn Văn Linh',
      email: 'test@example.com',
      avatarUrl: 'https://example.com/avatar-one.png',
    );
    await mount(tester);
    Image avatar() => tester.widget<Image>(
      find.byKey(const Key('traveler-home-avatar-image')),
    );
    expect(
      (avatar().image as NetworkImage).url,
      'https://example.com/avatar-one.png',
    );
    await mount(tester, active: false);
    repository.profile = const TravelerProfile(
      fullName: 'Nguyễn Văn Linh',
      email: 'test@example.com',
      avatarUrl: 'https://example.com/avatar-two.png',
    );
    await mount(tester);
    expect(
      (avatar().image as NetworkImage).url,
      'https://example.com/avatar-two.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing avatar uses a safe initial fallback', (tester) async {
    await mount(tester);
    expect(
      find.byKey(const Key('traveler-home-avatar-fallback')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('traveler-home-avatar-image')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
