import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/leave_travel_group_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/leave_travel_group_repository.dart';
import 'package:uuid/uuid.dart';

enum LeaveTravelGroupStatus {
  initial,
  submitting,
  success,
  uncertain,
  stale,
  failure,
}

final class LeaveTravelGroupState extends Equatable {
  const LeaveTravelGroupState({
    this.status = LeaveTravelGroupStatus.initial,
    this.result,
    this.message,
  });

  final LeaveTravelGroupStatus status;
  final LeaveTravelGroupResult? result;
  final String? message;

  @override
  List<Object?> get props => [status, result, message];
}

final class LeaveTravelGroupCubit extends Cubit<LeaveTravelGroupState> {
  LeaveTravelGroupCubit({
    required LeaveTravelGroupRepository repository,
    Uuid? uuid,
  }) : _repository = repository,
       _uuid = uuid ?? const Uuid(),
       super(const LeaveTravelGroupState());

  final LeaveTravelGroupRepository _repository;
  final Uuid _uuid;
  String? _idempotencyKey;

  Future<void> submit(int groupId) async {
    if (state.status == LeaveTravelGroupStatus.submitting ||
        state.status == LeaveTravelGroupStatus.success) {
      return;
    }
    if (groupId <= 0) {
      emit(
        const LeaveTravelGroupState(
          status: LeaveTravelGroupStatus.failure,
          message: 'This group is unavailable.',
        ),
      );
      return;
    }
    _idempotencyKey ??= _uuid.v4();
    emit(
      const LeaveTravelGroupState(status: LeaveTravelGroupStatus.submitting),
    );
    try {
      final result = await _repository.leaveTravelGroup(
        groupId: groupId,
        idempotencyKey: _idempotencyKey!,
      );
      if (isClosed) return;
      emit(
        LeaveTravelGroupState(
          status: LeaveTravelGroupStatus.success,
          result: result,
        ),
      );
    } on NetworkFailure {
      if (!isClosed) {
        emit(
          const LeaveTravelGroupState(
            status: LeaveTravelGroupStatus.uncertain,
            message:
                'We could not confirm whether you left. Check your connection and retry.',
          ),
        );
      }
    } on ServerFailure {
      if (!isClosed) {
        emit(
          const LeaveTravelGroupState(
            status: LeaveTravelGroupStatus.uncertain,
            message: 'We could not confirm whether you left. Please retry.',
          ),
        );
      }
    } on ConflictFailure {
      _idempotencyKey = null;
      if (!isClosed) {
        emit(
          const LeaveTravelGroupState(
            status: LeaveTravelGroupStatus.stale,
            message:
                'Group membership has changed. Please review the latest details.',
          ),
        );
      }
    } on Failure catch (failure) {
      if (failure is UnknownFailure) {
        if (!isClosed) {
          emit(
            const LeaveTravelGroupState(
              status: LeaveTravelGroupStatus.uncertain,
              message: 'We could not confirm whether you left. Please retry.',
            ),
          );
        }
        return;
      }
      _idempotencyKey = null;
      if (!isClosed) {
        emit(
          LeaveTravelGroupState(
            status: LeaveTravelGroupStatus.failure,
            message: switch (failure) {
              AuthenticationFailure() => 'Please sign in again to continue.',
              PermissionFailure() ||
              NotFoundFailure() => 'This group is no longer available to you.',
              _ => 'Unable to leave this group right now. Please try again.',
            },
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          const LeaveTravelGroupState(
            status: LeaveTravelGroupStatus.uncertain,
            message: 'We could not confirm whether you left. Please retry.',
          ),
        );
      }
    }
  }
}
