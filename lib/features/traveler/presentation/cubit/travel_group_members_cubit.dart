import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:uuid/uuid.dart';

/// Loads the privacy-safe, read-only UC19 group membership list.
final class TravelGroupMembersCubit extends Cubit<TravelGroupMembersState> {
  TravelGroupMembersCubit({
    required TravelGroupRepository repository,
    Uuid? uuid,
  }) : _repository = repository,
       _uuid = uuid ?? const Uuid(),
       super(const TravelGroupMembersInitial());

  final TravelGroupRepository _repository;
  final Uuid _uuid;
  int _loadVersion = 0;
  bool _removing = false;
  ({int groupId, int memberUserId, String key})? _uncertainAttempt;

  Future<void> removeMember({
    required int groupId,
    required int memberUserId,
  }) async {
    if (_removing || isClosed || state is! TravelGroupMembersSuccess) return;
    final members = (state as TravelGroupMembersSuccess).members;
    if (members.groupId != groupId ||
        !members.members.any(
          (member) => member.memberId == memberUserId && !member.isHost,
        )) {
      return;
    }
    _uncertainAttempt = (
      groupId: groupId,
      memberUserId: memberUserId,
      key: _uuid.v4(),
    );
    await _sendRemoval(members);
  }

  Future<void> retryRemoval() async {
    if (_removing ||
        isClosed ||
        state is! TravelGroupMembersRemovalRetryable ||
        _uncertainAttempt == null) {
      return;
    }
    await _sendRemoval((state as TravelGroupMembersRemovalRetryable).members);
  }

  Future<void> _sendRemoval(TravelGroupMembers members) async {
    final attempt = _uncertainAttempt;
    if (attempt == null) return;
    _removing = true;
    emit(TravelGroupMembersRemoving(members));
    try {
      final result = await _repository.removeGroupMember(
        groupId: attempt.groupId,
        memberUserId: attempt.memberUserId,
        idempotencyKey: attempt.key,
      );
      if (isClosed) return;
      if (result.groupId != attempt.groupId ||
          result.memberUserId != attempt.memberUserId) {
        _uncertainAttempt = null;
        emit(const TravelGroupMembersFailure());
        return;
      }
      // The response can be a replay of a past removal after the user rejoined.
      final current = await _repository.getTravelGroupMembers(
        groupId: attempt.groupId,
      );
      if (isClosed) return;
      _uncertainAttempt = null;
      if (current.members.any(
        (member) => member.memberId == attempt.memberUserId,
      )) {
        emit(
          TravelGroupMembersRemovalIssue(
            current,
            'Membership changed. Refresh the list before trying again.',
          ),
        );
      } else {
        emit(
          TravelGroupMembersSuccess(
            current,
            removedMemberName: result.memberName,
          ),
        );
      }
    } on AuthenticationFailure {
      if (!isClosed) emit(const TravelGroupMembersAuthenticationRequired());
      _uncertainAttempt = null;
    } on PermissionFailure {
      if (!isClosed) emit(const TravelGroupMembersPermissionDenied());
      _uncertainAttempt = null;
    } on NotFoundFailure {
      if (!isClosed) emit(const TravelGroupMembersNotFound());
      _uncertainAttempt = null;
    } on ConflictFailure {
      _uncertainAttempt = null;
      if (!isClosed) await load(groupId: attempt.groupId);
    } on ValidationFailure {
      _uncertainAttempt = null;
      if (!isClosed) {
        emit(
          TravelGroupMembersRemovalIssue(
            members,
            'Unable to remove this member. Please refresh and try again.',
          ),
        );
      }
    } on Failure {
      if (!isClosed) emit(TravelGroupMembersRemovalRetryable(members));
    } catch (_) {
      if (!isClosed) emit(TravelGroupMembersRemovalRetryable(members));
    } finally {
      _removing = false;
    }
  }

  Future<void> load({required int groupId}) async {
    if (isClosed) return;
    final version = ++_loadVersion;
    emit(const TravelGroupMembersLoading());
    try {
      final members = await _repository.getTravelGroupMembers(groupId: groupId);
      if (isClosed || version != _loadVersion) return;
      emit(TravelGroupMembersSuccess(members));
    } on AuthenticationFailure {
      if (isClosed || version != _loadVersion) return;
      emit(const TravelGroupMembersAuthenticationRequired());
    } on PermissionFailure {
      if (isClosed || version != _loadVersion) return;
      emit(const TravelGroupMembersPermissionDenied());
    } on NotFoundFailure {
      if (isClosed || version != _loadVersion) return;
      emit(const TravelGroupMembersNotFound());
    } on Failure {
      if (isClosed || version != _loadVersion) return;
      emit(const TravelGroupMembersFailure());
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
      emit(const TravelGroupMembersFailure());
    }
  }
}
