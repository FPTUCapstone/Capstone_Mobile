import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
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
  GroupInvitation? _pendingRegenerationInvitation;
  bool _operationInFlight = false;

  Future<void> loadInvitation(int groupId) async {
    if (isClosed || _operationInFlight || _pendingRegenerationKey != null) {
      return;
    }
    _operationInFlight = true;
    emit(const InviteGroupMembersState.loading());
    try {
      final invitation = await _repository.getOrCreateGroupInvitation(
        groupId: groupId,
        idempotencyKey: _uuid.v4(),
      );
      if (isClosed) return;
      emit(InviteGroupMembersState.success(invitation));
    } catch (error) {
      if (isClosed) return;
      emit(InviteGroupMembersState.failure(_errorMessage(error)));
    } finally {
      _operationInFlight = false;
    }
  }

  Future<void> regenerateInvitation(int groupId) async {
    if (isClosed || _operationInFlight) {
      return;
    }
    final currentInvitation =
        _pendingRegenerationInvitation ?? state.invitation;
    if (currentInvitation == null) return;

    final isReconciling = _pendingRegenerationKey != null;
    final idempotencyKey = _pendingRegenerationKey ??= _uuid.v4();
    _pendingRegenerationInvitation = currentInvitation;
    _operationInFlight = true;
    emit(
      InviteGroupMembersState.regenerating(
        isReconciling ? null : currentInvitation,
      ),
    );
    try {
      final invitation = await _repository.regenerateGroupInvitation(
        groupId: groupId,
        idempotencyKey: idempotencyKey,
      );
      if (isClosed) return;
      _pendingRegenerationKey = null;
      _pendingRegenerationInvitation = null;
      emit(InviteGroupMembersState.success(invitation));
    } catch (error) {
      if (isClosed) return;
      if (_isDefinitiveRegenerationFailure(error)) {
        _pendingRegenerationKey = null;
        _pendingRegenerationInvitation = null;
        emit(
          InviteGroupMembersState.failure(
            _errorMessage(error),
            invitation: !isReconciling && _canRetainInvitation(error)
                ? currentInvitation
                : null,
          ),
        );
      } else {
        emit(
          const InviteGroupMembersState.regenerationUncertain(
            'The invitation may have changed. Retry to confirm the current code.',
          ),
        );
      }
    } finally {
      _operationInFlight = false;
    }
  }

  bool _isDefinitiveRegenerationFailure(Object error) =>
      error is AuthenticationFailure ||
      error is PermissionFailure ||
      error is ValidationFailure ||
      error is NotFoundFailure ||
      error is ConflictFailure;

  bool _canRetainInvitation(Object error) =>
      error is ValidationFailure || error is ConflictFailure;

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
