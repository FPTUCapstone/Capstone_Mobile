import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

enum JoinTravelGroupStatus {
  initial,
  submitting,
  success,
  validationFailure,
  failure,
}

final class JoinTravelGroupState extends Equatable {
  const JoinTravelGroupState({
    required this.status,
    this.errorMessage,
    this.result,
    this.existingGroupId,
  });

  const JoinTravelGroupState.initial()
    : this(status: JoinTravelGroupStatus.initial);

  const JoinTravelGroupState.submitting()
    : this(status: JoinTravelGroupStatus.submitting);

  const JoinTravelGroupState.validationFailure(String message)
    : this(
        status: JoinTravelGroupStatus.validationFailure,
        errorMessage: message,
      );

  const JoinTravelGroupState.failure(String message, [int? existingGroupId])
    : this(
        status: JoinTravelGroupStatus.failure,
        errorMessage: message,
        existingGroupId: existingGroupId,
      );

  const JoinTravelGroupState.success(TravelGroup group)
    : this(status: JoinTravelGroupStatus.success, result: group);

  final JoinTravelGroupStatus status;
  final String? errorMessage;
  final TravelGroup? result;
  final int? existingGroupId;

  bool get isSubmitting => status == JoinTravelGroupStatus.submitting;

  @override
  List<Object?> get props => [status, errorMessage, result, existingGroupId];
}
