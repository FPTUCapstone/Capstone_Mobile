import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

final class TravelGroupDetailsRouteArgs extends Equatable {
  const TravelGroupDetailsRouteArgs({
    required this.group,
    required this.isHost,
  });

  final TravelGroup group;
  final bool isHost;

  @override
  List<Object?> get props => [group, isHost];
}
