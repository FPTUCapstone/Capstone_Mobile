import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';

/// Loads the privacy-safe, read-only UC19 group membership list.
final class TravelGroupMembersCubit extends Cubit<TravelGroupMembersState> {
  TravelGroupMembersCubit({required TravelGroupRepository repository})
    : _repository = repository,
      super(const TravelGroupMembersInitial());

  final TravelGroupRepository _repository;
  int _loadVersion = 0;

  Future<void> load({required int groupId}) async {
    if (isClosed) return;
    final version = ++_loadVersion;
    emit(const TravelGroupMembersLoading());
    try {
      final members = await _repository.getTravelGroupMembers(groupId: groupId);
      if (isClosed || version != _loadVersion) return;
      emit(TravelGroupMembersSuccess(members));
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
