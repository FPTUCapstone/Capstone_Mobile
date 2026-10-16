import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_route_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_map_data.dart';

void main() {
  const a = NavigationCoordinate(latitude: 16.0, longitude: 108.0);
  const b = NavigationCoordinate(latitude: 16.1, longitude: 108.1);
  const c = NavigationCoordinate(latitude: 16.2, longitude: 108.2);
  const legs = [
    ItineraryMapLeg(from: a, to: b, mode: TransportMode.walking),
    ItineraryMapLeg(from: b, to: c, mode: TransportMode.motorbike),
  ];

  test('routes each leg with its own transport', () async {
    final directions = _Directions();
    final cubit = ItineraryRouteCubit(directions: directions);
    addTearDown(cubit.close);

    await cubit.load(legs);

    expect(directions.modes, [TransportMode.walking, TransportMode.motorbike]);
    expect(cubit.state.lines, hasLength(2));
    expect(cubit.state.lines.first.points, hasLength(3));
    expect(cubit.state.lines.first.isStraight, isFalse);
  });

  test('a leg that cannot be routed is drawn straight', () async {
    final cubit = ItineraryRouteCubit(
      directions: _Directions(failOn: TransportMode.motorbike),
    );
    addTearDown(cubit.close);

    await cubit.load(legs);

    expect(cubit.state.lines.last.points, [b, c]);
    expect(cubit.state.lines.last.isStraight, isTrue);
  });

  test('legs already routed are not requested again after an edit', () async {
    final directions = _Directions();
    final cubit = ItineraryRouteCubit(directions: directions);
    addTearDown(cubit.close);

    await cubit.load(legs);
    await cubit.load([
      legs.first,
      const ItineraryMapLeg(from: b, to: c, mode: TransportMode.walking),
    ]);

    expect(directions.modes, [
      TransportMode.walking,
      TransportMode.motorbike,
      TransportMode.walking,
    ]);
  });

  test('without directions every leg is straight', () async {
    final cubit = ItineraryRouteCubit(directions: null);
    addTearDown(cubit.close);

    await cubit.load(legs);

    expect(cubit.state.lines.map((line) => line.isStraight), [true, true]);
  });
}

final class _Directions implements RouteDirectionsRepository {
  _Directions({this.failOn});

  final TransportMode? failOn;
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
    if (transportMode == failOn) throw const RoutingProviderFailure();
    return NavigationRoute(
      geometry: [
        origin,
        NavigationCoordinate(
          latitude: (origin.latitude + destination.latitude) / 2,
          longitude: origin.longitude,
        ),
        destination,
      ],
      distanceMeters: 1000,
      durationSeconds: 120,
      steps: const [],
    );
  }
}
