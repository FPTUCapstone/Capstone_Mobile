import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_detail_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_stop_card.dart';

import 'itinerary_detail_edit_test.dart';

/// Review 2 (D7): itinerary map with list sync; the CustomPaint fallback is
/// used here (no Mapbox token in tests).
void main() {
  Future<(EditRepository, _Directions)> pump(
    WidgetTester tester,
    ItineraryDetail detail, {
    List<ItineraryDetail> updates = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = EditRepository(detail)..updatedDetails.addAll(updates);
    final directions = _Directions();
    final cubit = ItineraryDetailCubit(repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: ItineraryDetailPage(
            itineraryId: 10,
            directionsRepository: directions,
            useMapbox: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (repository, directions);
  }

  bool highlighted(WidgetTester tester, String name) => tester
      .widget<ItineraryStopCard>(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(ItineraryStopCard),
        ),
      )
      .isHighlighted;

  testWidgets('draws numbered markers and routes each leg by its mode', (
    tester,
  ) async {
    final (_, directions) = await pump(tester, withStart(editablePlan()));

    expect(find.byKey(const Key('itinerary_map_canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('map_marker_10')), findsOneWidget);
    expect(find.byKey(const ValueKey('map_marker_30')), findsOneWidget);
    expect(directions.modes, [
      TransportMode.motorbike,
      TransportMode.motorbike,
      TransportMode.motorbike,
    ]);
  });

  testWidgets('tapping a marker highlights its stop in the list', (
    tester,
  ) async {
    await pump(tester, withStart(editablePlan()));

    expect(highlighted(tester, 'My Khe Beach'), isFalse);
    await tester.tap(find.byKey(const ValueKey('map_marker_20')));
    await tester.pumpAndSettle();

    expect(highlighted(tester, 'My Khe Beach'), isTrue);
    expect(highlighted(tester, 'Cham Museum'), isFalse);
  });

  testWidgets('tapping a stop highlights it on the map', (tester) async {
    await pump(tester, withStart(editablePlan()));

    await tester.tap(find.text('Noodle house'));
    await tester.pumpAndSettle();

    expect(highlighted(tester, 'Noodle house'), isTrue);
  });

  testWidgets('the route is redrawn after an edit', (tester) async {
    final walked = editablePlan(
      version: 2,
      items: [
        for (final item in editablePlan().items)
          item.poiId == 2
              ? planItem(
                  2,
                  'My Khe Beach',
                  item.plannedArrival,
                  travelMinutes: 30,
                  meters: 9400,
                  mode: TransportMode.walking,
                )
              : item,
      ],
    );
    final (_, directions) = await pump(
      tester,
      withStart(editablePlan()),
      updates: [withStart(walked)],
    );

    await tester.tap(find.text('Đổi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi bộ'));
    await tester.pumpAndSettle();

    expect(directions.modes.last, TransportMode.walking);
  });
}

ItineraryDetail withStart(ItineraryDetail plan) => ItineraryDetail(
  itineraryId: plan.itineraryId,
  schedulingRequestId: plan.schedulingRequestId,
  title: plan.title,
  version: plan.version,
  status: plan.status,
  validFrom: plan.validFrom,
  validTo: plan.validTo,
  canManage: plan.canManage,
  totalEstimatedCost: plan.totalEstimatedCost,
  totalDurationMinutes: plan.totalDurationMinutes,
  items: plan.items,
  transportMode: plan.transportMode,
  startLocation: const ItineraryLocation(latitude: 16.0, longitude: 108.2),
);

final class _Directions implements RouteDirectionsRepository {
  final modes = <TransportMode?>[];

  @override
  bool get isAvailable => true;

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    TransportMode? transportMode,
  }) async {
    modes.add(transportMode);
    return NavigationRoute(
      geometry: [origin, destination],
      distanceMeters: 1000,
      durationSeconds: 60,
      steps: const [],
    );
  }
}
