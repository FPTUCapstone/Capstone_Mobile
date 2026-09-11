import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_state.dart';

/// [UC-18] Cubit handling Invite Group Members use case.
///
/// Input: [TravelGroupRepository] injected via constructor.
/// Output: [InviteGroupMembersState] consumed by [InviteGroupMembersPage].
final class InviteGroupMembersCubit extends Cubit<InviteGroupMembersState> {
  InviteGroupMembersCubit({required TravelGroupRepository repository})
    : _repository = repository,
      super(const InviteGroupMembersState.initial());

  final TravelGroupRepository _repository;

  Future<void> loadInvitation(int groupId) async {
    emit(const InviteGroupMembersState.loading());
    try {
      final invitation = await _repository.getGroupInvitation(groupId);
      emit(InviteGroupMembersState.success(invitation));
    } on AuthenticationFailure {
      emit(
        const InviteGroupMembersState.failure(
          'Your session has expired. Please sign in again to continue.',
        ),
      );
    } on PermissionFailure {
      emit(
        const InviteGroupMembersState.failure(
          'You do not have permission to access this function.',
        ),
      );
    } on Failure {
      emit(
        const InviteGroupMembersState.failure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      );
    } catch (_) {
      emit(
        const InviteGroupMembersState.failure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      );
    }
  }
}
