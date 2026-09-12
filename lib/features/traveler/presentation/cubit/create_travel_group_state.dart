import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

enum CreateTravelGroupStatus {
  initial,
  submitting,
  success,
  failure,
  validationFailure,
}

/// State for [CreateTravelGroupCubit].
///
/// Input: status transitions from cubit methods.
/// Output: consumed by [CreateTravelGroupPage] via BlocConsumer/BlocBuilder.
final class CreateTravelGroupState extends Equatable {
  const CreateTravelGroupState._({
    required this.status,
    this.errorMessage,
    this.result,
  });

  const CreateTravelGroupState.initial()
    : this._(status: CreateTravelGroupStatus.initial);

  const CreateTravelGroupState.submitting()
    : this._(status: CreateTravelGroupStatus.submitting);

  const CreateTravelGroupState.success(TravelGroup group)
    : this._(status: CreateTravelGroupStatus.success, result: group);

  const CreateTravelGroupState.failure(String message)
    : this._(status: CreateTravelGroupStatus.failure, errorMessage: message);

  const CreateTravelGroupState.validationFailure(String message)
    : this._(
        status: CreateTravelGroupStatus.validationFailure,
        errorMessage: message,
      );

  final CreateTravelGroupStatus status;

  /// Non-null on [failure] and [validationFailure] states.
  final String? errorMessage;

  /// Non-null on [success] state.
  final TravelGroup? result;

  @override
  List<Object?> get props => [status, errorMessage, result];
}
