import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_location.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/group_location_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/group_location_publisher.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/location_sharing_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/location_sharing_page.dart';

void main() {
  testWidgets('shows private opt-in switch and permission warning', (
    tester,
  ) async {
    final cubit = LocationSharingCubit(
      repository: _Repository(),
      publisher: _Publisher(),
    );
    await cubit.load(42);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const LocationSharingPage(groupId: 42),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('share-location-switch')), findsOneWidget);
    expect(find.textContaining('active members'), findsWidgets);
    expect(find.textContaining('permission'), findsWidgets);
    expect(find.text('Open Device Settings'), findsOneWidget);
    await cubit.close();
  });
}

final class _Repository implements GroupLocationRepository {
  @override
  Future<List<int>> getEnabledGroupIds() async => [];
  @override
  Future<LocationSharingSetting> getSetting(int groupId) async =>
      LocationSharingSetting(groupId: groupId, enabled: false);
  @override
  Future<LocationSharingSetting> updateSetting(
    int groupId,
    bool enabled,
  ) async => LocationSharingSetting(groupId: groupId, enabled: enabled);
  @override
  Future<List<GroupLocation>> getLocations(int groupId) async => [];
  @override
  Future<void> publish(
    int groupId,
    DeviceGroupLocation location,
    String sessionVersion,
  ) async {}
  @override
  Future<void> clear(int groupId) async {}
}

final class _Publisher implements GroupLocationPublisher {
  @override
  Future<void> restoreActiveGroups() async {}
  @override
  Future<bool> ensurePermission({bool request = false}) async => false;
  @override
  Future<void> start(int groupId) async {}
  @override
  Future<void> stop(int groupId) async {}
  @override
  Future<void> suspend() async {}
  @override
  Future<void> pauseForPermission() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<bool> openSettings() async => true;
}
