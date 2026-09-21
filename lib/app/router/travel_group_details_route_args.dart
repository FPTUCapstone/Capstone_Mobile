import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

/// Route context supplied by a completed group operation.
final class TravelGroupDetailsRouteArgs {
  const TravelGroupDetailsRouteArgs({
    required this.group,
    required this.isHost,
  });

  final TravelGroup group;
  final bool isHost;
}
