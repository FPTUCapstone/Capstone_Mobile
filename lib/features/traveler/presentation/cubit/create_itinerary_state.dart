import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

enum CreateItineraryStatus { initial, generating, success, failure }

final class CreateItineraryState extends Equatable {
  const CreateItineraryState._({
    required this.status,
    this.result,
    this.message,
  });

  const CreateItineraryState.initial()
    : this._(status: CreateItineraryStatus.initial);
  const CreateItineraryState.generating()
    : this._(status: CreateItineraryStatus.generating);
  const CreateItineraryState.success(GeneratedItinerary result)
    : this._(status: CreateItineraryStatus.success, result: result);
  const CreateItineraryState.failure(String message)
    : this._(status: CreateItineraryStatus.failure, message: message);

  final CreateItineraryStatus status;
  final GeneratedItinerary? result;
  final String? message;

  @override
  List<Object?> get props => [status, result, message];
}
