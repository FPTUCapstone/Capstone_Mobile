import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';

sealed class TravelGroupMembersState extends Equatable {
  const TravelGroupMembersState();
}

final class TravelGroupMembersInitial extends TravelGroupMembersState {
  const TravelGroupMembersInitial();

  @override
  List<Object?> get props => const [];
}

final class TravelGroupMembersLoading extends TravelGroupMembersState {
  const TravelGroupMembersLoading();

  @override
  List<Object?> get props => const [];
}

final class TravelGroupMembersSuccess extends TravelGroupMembersState {
  const TravelGroupMembersSuccess(this.members);

  final TravelGroupMembers members;

  @override
  List<Object?> get props => [members];
}

final class TravelGroupMembersPermissionDenied extends TravelGroupMembersState {
  const TravelGroupMembersPermissionDenied();

  @override
  List<Object?> get props => const [];
}

final class TravelGroupMembersNotFound extends TravelGroupMembersState {
  const TravelGroupMembersNotFound();

  @override
  List<Object?> get props => const [];
}

final class TravelGroupMembersFailure extends TravelGroupMembersState {
  const TravelGroupMembersFailure();

  @override
  List<Object?> get props => const [];
}
