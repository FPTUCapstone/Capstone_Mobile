import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
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
    expect(cubit.state.message, 'Lịch trình này không khả dụng.');
  });

  test('load maps forbidden access to a view-specific message', () async {
    final cubit = ItineraryDetailCubit(
      repository: _Repository(loadFailure: const PermissionFailure()),
    );
    addTearDown(cubit.close);

    await cubit.load(10);

    expect(cubit.state.status, ItineraryDetailStatus.failure);
    expect(cubit.state.message, 'Bạn không có quyền xem lịch trình này.');
  });

  test('load maps a missing itinerary to a not-found message', () async {
    final cubit = ItineraryDetailCubit(
      repository: _Repository(loadFailure: const NotFoundFailure()),
    );
    addTearDown(cubit.close);

    await cubit.load(10);

    expect(cubit.state.status, ItineraryDetailStatus.failure);
    expect(cubit.state.message, 'Không tìm thấy lịch trình này.');
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
      await cubit.reorder([101]);
      await cubit.reorder([101]);
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
        pendingStops: const [ItineraryStop(poiId: 101)],
      ),
      ItineraryDetailState(
        status: ItineraryDetailStatus.failure,
        detail: _detail,
        pendingStops: const [ItineraryStop(poiId: 101)],
        message: 'TripMate chưa cập nhật được lịch trình. Vui lòng thử lại.',
      ),
      ItineraryDetailState(
        status: ItineraryDetailStatus.actionInProgress,
        detail: _detail,
        pendingStops: const [ItineraryStop(poiId: 101)],
      ),
      ItineraryDetailState(
        status: ItineraryDetailStatus.failure,
        detail: _detail,
        pendingStops: const [ItineraryStop(poiId: 101)],
        message: 'TripMate chưa cập nhật được lịch trình. Vui lòng thử lại.',
      ),
    ],
    verify: (_) {
      expect(retryRepository.keys, ['fixed-key', 'fixed-key']);
    },
  );

  group('stop edits', () {
    test('changing a leg sends every stop with that leg changed', () async {
      final repository = _Repository(loaded: _twoStops)
        ..updatedDetails.add(_twoStopsLater);
      final cubit = ItineraryDetailCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load(10);

      await cubit.changeLegMode(toPoiId: 202, mode: TransportMode.walking);

      expect(repository.sentStops.single, const [
        ItineraryStop(poiId: 201, transportModeToNext: TransportMode.walking),
        ItineraryStop(poiId: 202),
      ]);
      expect(cubit.state.status, ItineraryDetailStatus.loaded);
      expect(cubit.state.detail, _twoStopsLater);
      expect(cubit.state.shiftedArrivals, {202: 25});
      expect(cubit.state.undoStops, const [
        ItineraryStop(poiId: 201, transportModeToNext: TransportMode.motorbike),
        ItineraryStop(poiId: 202),
      ]);
      expect(cubit.state.editRevision, 1);
    });

    test('undo re-sends the previous stops once', () async {
      final repository = _Repository(loaded: _twoStops)
        ..updatedDetails.addAll([_twoStopsLater, _twoStops]);
      final cubit = ItineraryDetailCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load(10);
      await cubit.changeLegMode(toPoiId: 202, mode: TransportMode.walking);

      await cubit.undo();

      expect(repository.sentStops.last, const [
        ItineraryStop(poiId: 201, transportModeToNext: TransportMode.motorbike),
        ItineraryStop(poiId: 202),
      ]);
      expect(cubit.state.detail, _twoStops);
      expect(cubit.state.undoStops, isNull);
      expect(cubit.state.shiftedArrivals, {202: -25});
      expect(repository.keys.toSet(), hasLength(2));
    });

    test('a stop that does not fit is named in the message', () async {
      final repository = _Repository(
        loaded: _twoStops,
        failure: const StopInfeasibleFailure(
          poiId: 909,
          reason: 'ExceedsEndTime',
          overflowMinutes: 80,
        ),
      );
      final cubit = ItineraryDetailCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load(10);

      await cubit.insertStop(
        afterPoiId: 201,
        poiId: 909,
        poiName: 'Bún chả cá Bà Lữ',
      );

      expect(repository.sentStops.single, const [
        ItineraryStop(poiId: 201, transportModeToNext: TransportMode.motorbike),
        ItineraryStop(poiId: 909),
        ItineraryStop(poiId: 202),
      ]);
      expect(cubit.state.status, ItineraryDetailStatus.failure);
      expect(cubit.state.detail, _twoStops);
      expect(
        cubit.state.message,
        'Không thể lưu: Bún chả cá Bà Lữ vượt giờ kết thúc 1 giờ 20 phút.',
      );
    });

    test(
      'closed-at-arrival names an existing stop and its closing time',
      () async {
        final repository = _Repository(
          loaded: _twoStops,
          failure: const StopInfeasibleFailure(
            poiId: 202,
            reason: 'ClosedAtArrival',
            closesAt: '16:30',
          ),
        );
        final cubit = ItineraryDetailCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load(10);

        await cubit.removeStop(201);

        expect(repository.sentStops.single, const [ItineraryStop(poiId: 202)]);
        expect(
          cubit.state.message,
          'Không thể lưu: Beach đã đóng cửa khi đến nơi (đóng cửa lúc 16:30).',
        );
      },
    );

    test('replacing keeps the position', () async {
      final repository = _Repository(loaded: _twoStops);
      final cubit = ItineraryDetailCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load(10);

      await cubit.replaceStop(oldPoiId: 201, newPoiId: 301, poiName: 'Park');

      expect(repository.sentStops.single, const [
        ItineraryStop(poiId: 301, transportModeToNext: TransportMode.motorbike),
        ItineraryStop(poiId: 202),
      ]);
    });

    test('undo after the page closed does nothing', () async {
      final repository = _Repository(loaded: _twoStops)
        ..updatedDetails.add(_twoStopsLater);
      final cubit = ItineraryDetailCubit(repository: repository);
      await cubit.load(10);
      await cubit.changeLegMode(toPoiId: 202, mode: TransportMode.walking);
      await cubit.close();

      await cubit.undo();

      expect(repository.sentStops, hasLength(1));
    });

    test('a failed later edit keeps the undo of the previous one', () async {
      final repository = _Repository(loaded: _twoStops)
        ..updatedDetails.add(_twoStopsLater);
      final cubit = ItineraryDetailCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load(10);
      await cubit.changeLegMode(toPoiId: 202, mode: TransportMode.walking);
      final undo = cubit.state.undoStops;

      repository.failure = const NetworkFailure();
      await cubit.removeStop(201);

      expect(cubit.state.status, ItineraryDetailStatus.failure);
      expect(undo, isNotNull);
      expect(cubit.state.undoStops, undo);
    });

    test('edits are ignored while the trip is being navigated', () async {
      final repository = _Repository(loaded: _navigated);
      final cubit = ItineraryDetailCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load(10);

      await cubit.changeLegMode(toPoiId: 202, mode: TransportMode.walking);
      await cubit.removeStop(201);

      expect(repository.sentStops, isEmpty);
    });
  });
}

ItineraryDetailItem _visit(
  int itemId,
  int poiId,
  String name,
  DateTime arrival, {
  TransportMode? modeFromPrevious,
}) => ItineraryDetailItem(
  itemId: itemId,
  sequenceNo: itemId,
  poiId: poiId,
  poiName: name,
  category: 'Museum',
  itemKind: ItineraryItemKind.visit,
  plannedArrival: arrival,
  plannedDeparture: arrival.add(const Duration(hours: 1)),
  travelDurationFromPreviousMinutes: 20,
  stayDurationMinutes: 60,
  estimatedCost: null,
  isMandatory: false,
  recommendationReason: null,
  isUnavailable: false,
  transportModeFromPrevious: modeFromPrevious,
);

ItineraryDetail _plan(
  List<ItineraryDetailItem> items, {
  int version = 1,
  bool navigating = false,
}) => ItineraryDetail(
  itineraryId: 10,
  schedulingRequestId: 20,
  title: 'Day plan',
  version: version,
  status: 'Draft',
  validFrom: DateTime.utc(2026, 9, 20, 1),
  validTo: DateTime.utc(2026, 9, 20, 9),
  canManage: true,
  totalEstimatedCost: 0,
  totalDurationMinutes: 480,
  items: items,
  isNavigationInProgress: navigating,
  transportMode: TransportMode.motorbike,
);

final _twoStops = _plan([
  _visit(1, 201, 'Museum', DateTime.utc(2026, 9, 20, 1)),
  _visit(
    2,
    202,
    'Beach',
    DateTime.utc(2026, 9, 20, 2, 20),
    modeFromPrevious: TransportMode.motorbike,
  ),
]);

final _twoStopsLater = _plan(version: 2, [
  _visit(3, 201, 'Museum', DateTime.utc(2026, 9, 20, 1)),
  _visit(
    4,
    202,
    'Beach',
    DateTime.utc(2026, 9, 20, 2, 45),
    modeFromPrevious: TransportMode.walking,
  ),
]);

final _navigated = _plan(_twoStops.items, navigating: true);

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
  _Repository({
    this.failure,
    this.loadFailure,
    this.regeneratedDetail,
    this.loaded,
  });

  Failure? failure;
  final Failure? loadFailure;
  final ItineraryDetail? regeneratedDetail;
  final ItineraryDetail? loaded;
  final keys = <String>[];
  final regeneratedIds = <int>[];
  final acceptedIds = <int>[];
  final sentStops = <List<ItineraryStop>>[];
  final updatedDetails = <ItineraryDetail>[];

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    if (loadFailure != null) throw loadFailure!;
    return loaded ?? _detail;
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
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    sentStops.add(stops);
    if (failure != null) throw failure!;
    return updatedDetails.isEmpty ? _detail : updatedDetails.removeAt(0);
  }
}
