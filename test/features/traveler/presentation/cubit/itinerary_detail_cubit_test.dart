import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_state.dart';

void main() {
  late _Repository retryRepository;
  test('load rejects a non-positive deep-link ID', () async {
    final cubit = ItineraryDetailCubit(repository: _Repository());
    addTearDown(cubit.close);

    await cubit.load(0);

    expect(cubit.state.status, ItineraryDetailStatus.failure);
    expect(cubit.state.message, 'This itinerary is unavailable.');
  });

  test('load maps forbidden access to a view-specific message', () async {
    final cubit = ItineraryDetailCubit(
      repository: _Repository(loadFailure: const PermissionFailure()),
    );
    addTearDown(cubit.close);

    await cubit.load(10);

    expect(cubit.state.status, ItineraryDetailStatus.failure);
    expect(cubit.state.message, 'You do not have access to this itinerary.');
  });

  test('load maps a missing itinerary to a not-found message', () async {
    final cubit = ItineraryDetailCubit(
      repository: _Repository(loadFailure: const NotFoundFailure()),
    );
    addTearDown(cubit.close);

    await cubit.load(10);

    expect(cubit.state.status, ItineraryDetailStatus.failure);
    expect(cubit.state.message, 'This itinerary could not be found.');
  });

  test('uses the successor ID for mutations after regeneration', () async {
    final repository = _Repository(regeneratedDetail: _successorDetail);
    final cubit = ItineraryDetailCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load(10);
    await cubit.regenerate();
    await cubit.accept();

    expect(repository.regeneratedIds, [10]);
    expect(repository.acceptedIds, [15]);
  });

  blocTest<ItineraryDetailCubit, ItineraryDetailState>(
    'preserves the edit operation key when the same adjustment is retried',
    build: () {
      retryRepository = _Repository(failure: const NetworkFailure());
      return ItineraryDetailCubit(
        repository: retryRepository,
        operationKeyFactory: () => 'fixed-key',
      );
    },
    seed: () => ItineraryDetailState(
      status: ItineraryDetailStatus.loaded,
      detail: _detail,
    ),
    act: (cubit) async {
      await cubit.load(10);
      await cubit.adjustItems([101]);
      await cubit.adjustItems([101]);
    },
    expect: () => [
      ItineraryDetailState(
        status: ItineraryDetailStatus.loading,
        detail: _detail,
      ),
      ItineraryDetailState(
        status: ItineraryDetailStatus.loaded,
        detail: _detail,
      ),
      ItineraryDetailState(
        status: ItineraryDetailStatus.actionInProgress,
        detail: _detail,
        editingPoiIds: [101],
      ),
      ItineraryDetailState(
        status: ItineraryDetailStatus.failure,
        detail: _detail,
        editingPoiIds: [101],
        message: 'TripMate could not update this itinerary. Please try again.',
      ),
      ItineraryDetailState(
        status: ItineraryDetailStatus.actionInProgress,
        detail: _detail,
        editingPoiIds: [101],
      ),
      ItineraryDetailState(
        status: ItineraryDetailStatus.failure,
        detail: _detail,
        editingPoiIds: [101],
        message: 'TripMate could not update this itinerary. Please try again.',
      ),
    ],
    verify: (_) {
      expect(retryRepository.keys, ['fixed-key', 'fixed-key']);
    },
  );
}

final _detail = ItineraryDetail(
  itineraryId: 10,
  schedulingRequestId: 20,
  title: 'Day plan',
  version: 1,
  status: 'Draft',
  validFrom: DateTime.utc(2026, 9, 20, 1),
  validTo: DateTime.utc(2026, 9, 20, 5),
  canManage: true,
  totalEstimatedCost: 0,
  totalDurationMinutes: 240,
  items: [
    ItineraryDetailItem(
      itemId: 1,
      sequenceNo: 1,
      poiId: 101,
      poiName: 'Museum',
      category: 'Museum',
      itemKind: ItineraryItemKind.visit,
      plannedArrival: DateTime.utc(2026, 9, 20, 1),
      plannedDeparture: DateTime.utc(2026, 9, 20, 2),
      travelDurationFromPreviousMinutes: null,
      stayDurationMinutes: 60,
      estimatedCost: null,
      isMandatory: false,
      recommendationReason: null,
      isUnavailable: false,
    ),
  ],
);

final _successorDetail = ItineraryDetail(
  itineraryId: 15,
  schedulingRequestId: 20,
  title: 'Day plan',
  version: 2,
  status: 'Draft',
  validFrom: DateTime.utc(2026, 9, 20, 1),
  validTo: DateTime.utc(2026, 9, 20, 5),
  canManage: true,
  totalEstimatedCost: 0,
  totalDurationMinutes: 240,
  items: _detail.items,
);

final class _Repository implements ItineraryRepository {
  _Repository({this.failure, this.loadFailure, this.regeneratedDetail});

  final Failure? failure;
  final Failure? loadFailure;
  final ItineraryDetail? regeneratedDetail;
  final keys = <String>[];
  final regeneratedIds = <int>[];
  final acceptedIds = <int>[];

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    if (loadFailure != null) throw loadFailure!;
    return _detail;
  }

  @override
  Future<ItineraryDetail> accept(int itineraryId) async {
    acceptedIds.add(itineraryId);
    return regeneratedDetail ?? _detail;
  }

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) async {
    regeneratedIds.add(itineraryId);
    return regeneratedDetail ?? _detail;
  }

  @override
  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (failure != null) throw failure!;
    return _detail;
  }
}
