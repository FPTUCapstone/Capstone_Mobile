import 'package:equatable/equatable.dart';

final class CreateTravelGroupRouteArgs extends Equatable {
  const CreateTravelGroupRouteArgs({
    required this.itineraryId,
    required this.itineraryTitle,
  });

  final int itineraryId;
  final String itineraryTitle;

  @override
  List<Object?> get props => [itineraryId, itineraryTitle];
}
