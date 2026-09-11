import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';

enum InviteGroupMembersStatus { initial, loading, success, failure }

/// [UC-18] State for InviteGroupMembersCubit.
final class InviteGroupMembersState extends Equatable {
  const InviteGroupMembersState({
    required this.status,
    this.invitation,
    this.errorMessage,
  });

  const InviteGroupMembersState.initial()
    : this(status: InviteGroupMembersStatus.initial);

  const InviteGroupMembersState.loading()
    : this(status: InviteGroupMembersStatus.loading);

  const InviteGroupMembersState.success(GroupInvitation invitation)
    : this(status: InviteGroupMembersStatus.success, invitation: invitation);

  const InviteGroupMembersState.failure(String errorMessage)
    : this(
        status: InviteGroupMembersStatus.failure,
        errorMessage: errorMessage,
      );

  final InviteGroupMembersStatus status;
  final GroupInvitation? invitation;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, invitation, errorMessage];
}
