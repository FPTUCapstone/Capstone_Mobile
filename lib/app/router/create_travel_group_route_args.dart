import 'package:equatable/equatable.dart';

final class CreateTravelGroupRouteArgs extends Equatable {
  const CreateTravelGroupRouteArgs({
    required this.itineraryId,
    required this.itineraryTitle,
    this.destination,
    this.dateRange,
  });

  final int itineraryId;
  final String itineraryTitle;
  final String? destination;
  final String? dateRange;

  @override
  List<Object?> get props => [itineraryId, itineraryTitle, destination, dateRange];
}
