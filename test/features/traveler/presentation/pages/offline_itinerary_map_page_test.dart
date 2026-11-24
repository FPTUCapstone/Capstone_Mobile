import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_itinerary_map_page.dart';
import '../../support/offline_fixture.dart';

void main() {
  test('an endpoint-only cached trip starts inside its downloaded area', () {
    final manifest = offlineFixture(
      startLocation: const ItineraryLocation(
        latitude: 16.04,
        longitude: 108.22,
      ),
    );
    expect(
      offlineMapInitialFocus(manifest),
      const NavigationCoordinate(latitude: 16.04, longitude: 108.22),
    );
  });
  testWidgets(
    'cached map uses saved style and remains readable after denied GPS',
    (tester) async {
      final repo = FakeOfflineRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineItineraryMapPage(
            itineraryId: 10,
            repository: repo,
            locationTracker: _DeniedLocation(),
            mapBuilder: (_, manifest, showLocation) =>
                Text('Saved style: ${manifest.styleUri}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('mapbox://styles/mapbox/standard'),
        findsOneWidget,
      );
      expect(repo.calls, ['read']);
      await tester.tap(find.byTooltip('Vị trí của tôi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có quyền vị trí'), findsOneWidget);
      expect(find.textContaining('Saved style:'), findsOneWidget);
    },
  );
}

class _DeniedLocation implements NavigationLocationTracker {
  @override
  Future<NavigationLocationAccess> ensureAccess() async =>
      NavigationLocationAccess.denied;
  @override
  Stream<NavigationPosition> watchPosition() => const Stream.empty();
  @override
  Future<bool> openAppSettings() async => false;
  @override
  Future<bool> openLocationSettings() async => false;
}
