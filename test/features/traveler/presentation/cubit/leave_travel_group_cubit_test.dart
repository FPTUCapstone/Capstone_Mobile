import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/leave_travel_group_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/leave_travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/leave_travel_group_cubit.dart';

void main() {
  test('confirmed leave reports the committed server outcome', () async {
    final repository = _LeaveRepository();
    final cubit = LeaveTravelGroupCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.submit(42);

    expect(cubit.state.status, LeaveTravelGroupStatus.success);
    expect(cubit.state.result?.newHostUserId, 17);
    expect(repository.groupIds, [42]);
    expect(repository.keys.single, isNotEmpty);
  });

  test('uncertain network response retries with the same key', () async {
    final repository = _LeaveRepository()..failure = const NetworkFailure();
    final cubit = LeaveTravelGroupCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.submit(42);
    expect(cubit.state.status, LeaveTravelGroupStatus.uncertain);

    repository.failure = null;
    await cubit.submit(42);
    expect(cubit.state.status, LeaveTravelGroupStatus.success);
    expect(repository.keys[0], repository.keys[1]);
  });

  test(
    'unreadable success response keeps the key for safe reconciliation',
    () async {
      final repository = _LeaveRepository()..failure = const UnknownFailure();
      final cubit = LeaveTravelGroupCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.submit(42);
      expect(cubit.state.status, LeaveTravelGroupStatus.uncertain);
      final key = repository.keys.single;
      repository.failure = null;
      await cubit.submit(42);
      expect(repository.keys.last, key);
    },
  );

  test('double submit sends only one request', () async {
    final repository = _LeaveRepository()..pending = Completer<void>();
    final cubit = LeaveTravelGroupCubit(repository: repository);
    addTearDown(cubit.close);

    final first = cubit.submit(42);
    await cubit.submit(42);
    expect(repository.groupIds, [42]);
    repository.pending!.complete();
    await first;
  });

  test('conflict marks preview stale without claiming success', () async {
    final repository = _LeaveRepository()..failure = const ConflictFailure();
    final cubit = LeaveTravelGroupCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.submit(42);
    expect(cubit.state.status, LeaveTravelGroupStatus.stale);
    expect(cubit.state.result, isNull);
  });
}

final class _LeaveRepository implements LeaveTravelGroupRepository {
  final groupIds = <int>[];
  final keys = <String>[];
  Failure? failure;
  Completer<void>? pending;

  @override
  Future<LeaveTravelGroupResult> leaveTravelGroup({
    required int groupId,
    required String idempotencyKey,
  }) async {
    groupIds.add(groupId);
    keys.add(idempotencyKey);
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    return LeaveTravelGroupResult(
      groupId: groupId,
      membershipStatus: 'Left',
      groupClosed: false,
      newHostUserId: 17,
      leftAtUtc: DateTime.utc(2026, 10, 25),
    );
  }
}
