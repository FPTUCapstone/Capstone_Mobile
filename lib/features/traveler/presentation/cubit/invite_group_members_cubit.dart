import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_state.dart';
import 'package:uuid/uuid.dart';

/// [UC-18] Cubit handling Invite Group Members use case.
///
/// Input: [TravelGroupRepository] injected via constructor.
/// Output: [InviteGroupMembersState] consumed by [InviteGroupMembersPage].
final class InviteGroupMembersCubit extends Cubit<InviteGroupMembersState> {
  InviteGroupMembersCubit({
    required TravelGroupRepository repository,
    Uuid? uuid,
  }) : _repository = repository,
       _uuid = uuid ?? Uuid(),
       super(const InviteGroupMembersState.initial());

  final TravelGroupRepository _repository;
  final Uuid _uuid;
  String? _pendingRegenerationKey;

  Future<void> loadInvitation(int groupId) async {
    emit(const InviteGroupMembersState.loading());
    try {
      final invitation = await _repository.getOrCreateGroupInvitation(
        groupId: groupId,
        idempotencyKey: _uuid.v4(),
      );
      emit(InviteGroupMembersState.success(invitation));
    } catch (error) {
      emit(InviteGroupMembersState.failure(_errorMessage(error)));
    }
  }

  Future<void> regenerateInvitation(int groupId) async {
    final currentInvitation = state.invitation;
    if (currentInvitation == null ||
        state.status == InviteGroupMembersStatus.regenerating) {
      return;
    }

    final idempotencyKey = _pendingRegenerationKey ??= _uuid.v4();
    emit(InviteGroupMembersState.regenerating(currentInvitation));
    try {
      final invitation = await _repository.regenerateGroupInvitation(
        groupId: groupId,
        idempotencyKey: idempotencyKey,
      );
      _pendingRegenerationKey = null;
      emit(InviteGroupMembersState.success(invitation));
    } catch (error) {
      emit(
        InviteGroupMembersState.failure(
          _errorMessage(error),
          invitation: currentInvitation,
        ),
      );
    }
  }

  String _errorMessage(Object error) {
    if (error is AuthenticationFailure) {
      return 'Your session has expired. Please sign in again to continue.';
    }
    if (error is PermissionFailure) {
      return 'You do not have permission to access this function.';
    }
    return 'TripMate is temporarily unable to process your request. Please check your connection and try again.';
  }
}
