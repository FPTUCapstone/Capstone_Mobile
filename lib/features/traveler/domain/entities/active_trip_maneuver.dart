import 'package:equatable/equatable.dart';

enum ManeuverDirection { straight, turnLeft, turnRight, uTurn, arrive }

final class ActiveTripManeuver extends Equatable {
  const ActiveTripManeuver({
    required this.instruction,
    required this.distanceMeters,
    required this.direction,
  });

  final String instruction;
  final int distanceMeters;
  final ManeuverDirection direction;

  @override
  List<Object?> get props => [instruction, distanceMeters, direction];
}
