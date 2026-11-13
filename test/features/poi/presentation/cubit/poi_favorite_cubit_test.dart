import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_favorite_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_favorite_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/set_poi_favorite_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_favorite_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_favorite_state.dart';

void main() {
  PoiFavoriteCubit build(FakePoiFavoriteRepository repository) {
    final cubit = PoiFavoriteCubit(
      getFavorite: GetPoiFavoriteUseCase(repository),
      setFavorite: SetPoiFavoriteUseCase(repository),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('load reflects the saved mark', () async {
    final repository = FakePoiFavoriteRepository(saved: true);
    final cubit = build(repository);

    await cubit.load(12);

    expect(cubit.state, const PoiFavoriteState(isFavorite: true));
    expect(repository.calls, ['get:12']);
  });

  test('a failed load leaves the heart off without an error', () async {
    final cubit = build(
      FakePoiFavoriteRepository(loadFailure: const NetworkFailure()),
    );

    await cubit.load(12);

    expect(cubit.state, const PoiFavoriteState());
  });

  test(
    'toggling turns the mark on at once, then keeps the saved value',
    () async {
      final repository = FakePoiFavoriteRepository()
        ..pendingSave = Completer<void>();
      final cubit = build(repository);
      await cubit.load(12);

      final toggled = cubit.toggle();

      expect(
        cubit.state,
        const PoiFavoriteState(
          isFavorite: true,
          status: PoiFavoriteStatus.saving,
        ),
      );
      repository.pendingSave!.complete();
      await toggled;
      expect(cubit.state, const PoiFavoriteState(isFavorite: true));
      expect(repository.calls, ['get:12', 'set:12:true']);
    },
  );

  test('toggling a saved mark turns it off', () async {
    final repository = FakePoiFavoriteRepository(saved: true);
    final cubit = build(repository);
    await cubit.load(12);

    await cubit.toggle();

    expect(cubit.state, const PoiFavoriteState());
    expect(repository.calls, ['get:12', 'set:12:false']);
  });

  test('a failed save rolls the mark back and reports it', () async {
    final repository = FakePoiFavoriteRepository(saved: true)
      ..saveFailure = const NetworkFailure();
    final cubit = build(repository);
    await cubit.load(12);
    final states = <PoiFavoriteState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);

    await cubit.toggle();
    await Future<void>.delayed(Duration.zero);

    expect(states, const [
      PoiFavoriteState(status: PoiFavoriteStatus.saving),
      PoiFavoriteState(isFavorite: true, status: PoiFavoriteStatus.saveFailed),
    ]);
  });

  test('a second tap while saving is ignored', () async {
    final repository = FakePoiFavoriteRepository()
      ..pendingSave = Completer<void>();
    final cubit = build(repository);
    await cubit.load(12);

    final first = cubit.toggle();
    await cubit.toggle();
    repository.pendingSave!.complete();
    await first;

    expect(repository.calls, ['get:12', 'set:12:true']);
  });

  test('a slow load never overwrites a tap made meanwhile', () async {
    final repository = FakePoiFavoriteRepository()
      ..pendingLoad = Completer<void>();
    final cubit = build(repository);

    final loading = cubit.load(12);
    await cubit.toggle();
    repository.pendingLoad!.complete();
    await loading;

    expect(cubit.state, const PoiFavoriteState(isFavorite: true));
  });
}

/// In-memory favorite mark, shared with the page test.
final class FakePoiFavoriteRepository implements PoiFavoriteRepository {
  FakePoiFavoriteRepository({this.saved = false, this.loadFailure});

  bool saved;
  final Failure? loadFailure;
  Failure? saveFailure;

  /// When set, the call waits for it (to observe the state in between).
  Completer<void>? pendingLoad;
  Completer<void>? pendingSave;
  final calls = <String>[];

  @override
  Future<bool> isFavorite(int poiId) async {
    calls.add('get:$poiId');
    final answer = saved;
    await pendingLoad?.future;
    if (loadFailure case final failure?) throw failure;
    return answer;
  }

  @override
  Future<bool> setFavorite(int poiId, {required bool isFavorite}) async {
    calls.add('set:$poiId:$isFavorite');
    await pendingSave?.future;
    if (saveFailure case final failure?) throw failure;
    return saved = isFavorite;
  }
}
