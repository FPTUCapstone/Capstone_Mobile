import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/pending_explanation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_state.dart';

const _template = 'Template sentence';
const _ai = 'AI sentence';

/// An answer the test completes by hand through [_Repository.late].
const _held = Object();

final _base = DateTime.utc(2026, 11, 17, 10);

ItineraryDetail _detail(int id, String sentence) => ItineraryDetail(
  itineraryId: id,
  schedulingRequestId: 20,
  title: 'Trip $id',
  version: 1,
  status: 'Draft',
  validFrom: null,
  validTo: null,
  canManage: true,
  totalEstimatedCost: 0,
  totalDurationMinutes: 60,
  items: [
    ItineraryDetailItem(
      itemId: 1,
      sequenceNo: 1,
      poiId: 7,
      poiName: 'Place',
      category: null,
      itemKind: ItineraryItemKind.visit,
      plannedArrival: DateTime.utc(2026, 9, 20, 1),
      plannedDeparture: DateTime.utc(2026, 9, 20, 2),
      travelDurationFromPreviousMinutes: null,
      stayDurationMinutes: 60,
      estimatedCost: null,
      isMandatory: false,
      recommendationReason: 'Reason',
      isUnavailable: false,
      friendlyExplanation: sentence,
    ),
  ],
);

PendingExplanation _pending({int id = 10}) => PendingExplanation(
  itineraryId: id,
  createdAt: _base,
  template: const {1: _template},
);

String? _sentence(ItineraryDetailCubit cubit) =>
    cubit.state.detail?.items.single.friendlyExplanation;

/// Answers `getById` from a queue; the last answer repeats. An entry may be a
/// [Failure] (thrown) or [_held] (waits for [late]).
final class _Repository implements ItineraryRepository {
  _Repository(this.answers, {this.acceptedDetail});

  final List<Object> answers;
  final ItineraryDetail? acceptedDetail;
  final late = Completer<ItineraryDetail>();
  int getByIdCalls = 0;

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    getByIdCalls++;
    final next = answers.length > 1 ? answers.removeAt(0) : answers.first;
    if (next is Failure) throw next;
    if (identical(next, _held)) return late.future;
    return next as ItineraryDetail;
  }

  @override
  Future<ItineraryDetail> accept(int itineraryId) async => acceptedDetail!;

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
    Map<int, StopRemovalReason> removalReasons = const {},
  }) => throw UnimplementedError();
}

typedef _Body =
    void Function(
      FakeAsync async,
      ItineraryDetailCubit cubit,
      _Repository repo,
    );

/// Runs [body] with a cubit whose clock follows the fake time. The repository
/// is built inside the fake zone, so its [Completer] resumes the awaiting
/// code inside that zone too.
void _run(_Repository Function() build, _Body body) {
  fakeAsync((async) {
    final repository = build();
    final cubit = ItineraryDetailCubit(
      repository: repository,
      now: () => _base.add(async.elapsed),
    );
    body(async, cubit, repository);
    if (!cubit.isClosed) cubit.close();
    async.flushMicrotasks();
  });
}

_Repository Function() _answers(
  List<Object> answers, {
  ItineraryDetail? acceptedDetail,
}) =>
    () => _Repository(answers, acceptedDetail: acceptedDetail);

Duration _ms(int value) => Duration(milliseconds: value);

void main() {
  test('makes no attempt without a pending explanation', () {
    _run(_answers([_detail(10, _template)]), (async, cubit, repo) {
      cubit.load(10);
      async.elapse(const Duration(seconds: 200));

      expect(repo.getByIdCalls, 1);
    });
  });

  test('loads again at 20, 45, 75 and 110 s after the create, then stops', () {
    _run(_answers([_detail(10, _template)]), (async, cubit, repo) {
      cubit.load(10, pendingExplanation: _pending());
      async.flushMicrotasks();
      expect(repo.getByIdCalls, 1);

      async.elapse(_ms(19900));
      expect(repo.getByIdCalls, 1);
      async.elapse(_ms(100));
      expect(repo.getByIdCalls, 2);
      async.elapse(const Duration(seconds: 25));
      expect(repo.getByIdCalls, 3);
      async.elapse(const Duration(seconds: 30));
      expect(repo.getByIdCalls, 4);
      async.elapse(const Duration(seconds: 35));
      expect(repo.getByIdCalls, 5);
      async.elapse(const Duration(seconds: 300));
      expect(repo.getByIdCalls, 5);
      expect(_sentence(cubit), _template);
    });
  });

  test(
    'measures the schedule from the create, so a passed delay is skipped',
    () {
      _run(_answers([_detail(10, _template)]), (async, cubit, repo) {
        async.elapse(const Duration(seconds: 30));
        cubit.load(10, pendingExplanation: _pending());
        async.flushMicrotasks();

        async.elapse(_ms(14900));
        expect(repo.getByIdCalls, 1);
        async.elapse(_ms(100));
        expect(repo.getByIdCalls, 2);
        async.elapse(const Duration(seconds: 300));
        expect(repo.getByIdCalls, 4);
      });
    },
  );

  test('stops at once when the AI sentence arrived and shows it', () {
    _run(
      _answers([
        _detail(10, _template),
        _detail(10, _template),
        _detail(10, _ai),
      ]),
      (async, cubit, repo) {
        cubit.load(10, pendingExplanation: _pending());
        async.elapse(const Duration(seconds: 45));

        expect(_sentence(cubit), _ai);
        expect(cubit.state.status, ItineraryDetailStatus.loaded);
        expect(repo.getByIdCalls, 3);

        async.elapse(const Duration(seconds: 300));
        expect(repo.getByIdCalls, 3);
      },
    );
  });

  test('ignores a failed attempt and still runs the later ones', () {
    _run(
      _answers([
        _detail(10, _template),
        const NetworkFailure(),
        _detail(10, _ai),
      ]),
      (async, cubit, repo) {
        cubit.load(10, pendingExplanation: _pending());
        async.elapse(const Duration(seconds: 45));

        expect(repo.getByIdCalls, 3);
        expect(_sentence(cubit), _ai);
      },
    );
  });

  test('makes no attempt when the first load already has the AI sentence', () {
    _run(_answers([_detail(10, _ai)]), (async, cubit, repo) {
      cubit.load(10, pendingExplanation: _pending());
      async.elapse(const Duration(seconds: 200));

      expect(repo.getByIdCalls, 1);
    });
  });

  test('makes no attempt when loaded after the last delay', () {
    _run(_answers([_detail(10, _template)]), (async, cubit, repo) {
      async.elapse(const Duration(seconds: 111));
      cubit.load(10, pendingExplanation: _pending());
      async.elapse(const Duration(seconds: 200));

      expect(repo.getByIdCalls, 1);
    });
  });

  test('ignores a pending explanation of another itinerary', () {
    _run(_answers([_detail(10, _template)]), (async, cubit, repo) {
      cubit.load(10, pendingExplanation: _pending(id: 99));
      async.elapse(const Duration(seconds: 200));

      expect(repo.getByIdCalls, 1);
    });
  });

  test('a result that arrives after close() is dropped without error', () {
    _run(_answers([_detail(10, _template), _held]), (async, cubit, repo) {
      cubit.load(10, pendingExplanation: _pending());
      async.elapse(const Duration(seconds: 20));
      expect(repo.getByIdCalls, 2);

      cubit.close();
      repo.late.complete(_detail(10, _ai));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 300));

      expect(_sentence(cubit), _template);
      expect(repo.getByIdCalls, 2);
    });
  });

  test('a new itinerary id stops the attempts for the old one', () {
    _run(
      _answers([_detail(10, _template)], acceptedDetail: _detail(11, 'New')),
      (async, cubit, repo) {
        cubit.load(10, pendingExplanation: _pending());
        async.flushMicrotasks();

        cubit.accept();
        async.flushMicrotasks();
        expect(cubit.state.detail!.itineraryId, 11);

        async.elapse(const Duration(seconds: 300));
        expect(repo.getByIdCalls, 1);
      },
    );
  });

  test(
    'an in-flight result for the old id never overwrites the new version',
    () {
      _run(
        _answers([
          _detail(10, _template),
          _held,
        ], acceptedDetail: _detail(11, 'New version')),
        (async, cubit, repo) {
          cubit.load(10, pendingExplanation: _pending());
          async.elapse(const Duration(seconds: 20));
          expect(repo.getByIdCalls, 2);

          cubit.accept();
          async.flushMicrotasks();
          repo.late.complete(_detail(10, _ai));
          async.flushMicrotasks();

          expect(cubit.state.detail!.itineraryId, 11);
          expect(_sentence(cubit), 'New version');
        },
      );
    },
  );

  test('copyWithDetail keeps every other part of the state', () {
    final state = ItineraryDetailState(
      status: ItineraryDetailStatus.actionInProgress,
      detail: _detail(10, _template),
      message: 'message',
      shiftedArrivals: const {7: 15},
      editRevision: 3,
    );

    final copy = state.copyWithDetail(_detail(10, _ai));

    expect(copy.detail!.items.single.friendlyExplanation, _ai);
    expect(copy.status, ItineraryDetailStatus.actionInProgress);
    expect(copy.message, 'message');
    expect(copy.shiftedArrivals, const {7: 15});
    expect(copy.editRevision, 3);
  });
}
