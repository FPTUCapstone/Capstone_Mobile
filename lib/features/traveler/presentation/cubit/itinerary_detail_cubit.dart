import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/pending_explanation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/itinerary_explanation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/itinerary_stops.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';

final class ItineraryDetailCubit extends Cubit<ItineraryDetailState> {
  ItineraryDetailCubit({
    required ItineraryRepository repository,
    String Function()? operationKeyFactory,
    DateTime Function()? now,
  }) : _repository = repository,
       _operationKeyFactory = operationKeyFactory ?? _createUuidV4,
       _now = now ?? DateTime.now,
       super(const ItineraryDetailState.initial());

  final ItineraryRepository _repository;
  final String Function() _operationKeyFactory;
  final DateTime Function() _now;
  final _explanationTimers = <Timer>[];
  int? _itineraryId;
  String? _operationKey;
  String? _operationFingerprint;

  /// Loads the itinerary. With a [pendingExplanation] of this itinerary (a
  /// create that answered `explanationPending: true`) it then loads again at
  /// the scheduled times until the AI sentences arrive.
  Future<void> load(
    int itineraryId, {
    PendingExplanation? pendingExplanation,
  }) async {
    _cancelExplanationRefresh();
    if (itineraryId <= 0) {
      emit(
        const ItineraryDetailState(
          status: ItineraryDetailStatus.failure,
          message: 'Lịch trình này không khả dụng.',
        ),
      );
      return;
    }
    _itineraryId = itineraryId;
    emit(
      ItineraryDetailState(
        status: ItineraryDetailStatus.loading,
        detail: state.detail,
      ),
    );
    try {
      final detail = await _repository.getById(itineraryId);
      if (isClosed) return;
      _resetOperation();
      emit(
        ItineraryDetailState(
          status: ItineraryDetailStatus.loaded,
          detail: detail,
        ),
      );
      if (pendingExplanation != null &&
          pendingExplanation.itineraryId == itineraryId) {
        _scheduleExplanationRefresh(pendingExplanation, detail);
      }
    } catch (error) {
      if (isClosed) return;
      emit(_loadFailure(error));
    }
  }

  void _scheduleExplanationRefresh(
    PendingExplanation pending,
    ItineraryDetail initial,
  ) {
    if (hasNewExplanation(pending.template, initial.items)) return;
    final now = _now();
    for (final delay in explanationRefreshDelays) {
      final wait = pending.createdAt.add(delay).difference(now);
      if (wait > Duration.zero) {
        _explanationTimers.add(Timer(wait, () => _refreshExplanation(pending)));
      }
    }
  }

  /// One scheduled attempt. A failure is ignored: the later attempts still run
  /// and the page keeps what it shows.
  Future<void> _refreshExplanation(PendingExplanation pending) async {
    final itineraryId = pending.itineraryId;
    final ItineraryDetail fresh;
    try {
      fresh = await _repository.getById(itineraryId);
    } catch (_) {
      return;
    }
    final current = state.detail;
    if (isClosed ||
        current == null ||
        current.itineraryId != itineraryId ||
        !hasNewExplanation(pending.template, fresh.items)) {
      return;
    }
    _cancelExplanationRefresh();
    emit(state.copyWithDetail(mergeExplanations(current, fresh)));
  }

  void _cancelExplanationRefresh() {
    for (final timer in _explanationTimers) {
      timer.cancel();
    }
    _explanationTimers.clear();
  }

  @override
  Future<void> close() {
    _cancelExplanationRefresh();
    return super.close();
  }

  Future<void> accept() async {
    final itineraryId = _itineraryId;
    if (itineraryId == null ||
        state.detail?.canManage != true ||
        state.isBusy) {
      return;
    }
    emit(
      ItineraryDetailState(
        status: ItineraryDetailStatus.actionInProgress,
        detail: state.detail,
      ),
    );
    try {
      final detail = await _repository.accept(itineraryId);
      if (isClosed) return;
      _itineraryId = detail.itineraryId;
      _cancelExplanationRefresh();
      _resetOperation();
      emit(
        ItineraryDetailState(
          status: ItineraryDetailStatus.loaded,
          detail: detail,
        ),
      );
    } catch (error) {
      if (!isClosed) emit(_failure(error));
    }
  }

  Future<void> regenerate() async {
    final itineraryId = _itineraryId;
    if (itineraryId == null ||
        state.detail?.canManage != true ||
        state.isBusy) {
      return;
    }
    final key = _keyFor('regenerate');
    emit(
      ItineraryDetailState(
        status: ItineraryDetailStatus.actionInProgress,
        detail: state.detail,
      ),
    );
    try {
      final detail = await _repository.regenerate(
        itineraryId: itineraryId,
        idempotencyKey: key,
      );
      if (isClosed) return;
      _itineraryId = detail.itineraryId;
      _cancelExplanationRefresh();
      _resetOperation();
      emit(
        ItineraryDetailState(
          status: ItineraryDetailStatus.loaded,
          detail: detail,
        ),
      );
    } catch (error) {
      if (!isClosed) emit(_failure(error));
    }
  }

  /// Puts the visit stops in this order (leaving out the others).
  /// [removalReasons] tells, by POI ID, why a stop was left out.
  Future<void> reorder(
    List<int> orderedVisitPoiIds, {
    Map<int, StopRemovalReason> removalReasons = const {},
  }) async {
    final detail = state.detail;
    if (detail == null) return;
    final ids = List<int>.unmodifiable(orderedVisitPoiIds);
    if (ids.isEmpty || ids.toSet().length != ids.length) {
      emit(
        ItineraryDetailState(
          status: ItineraryDetailStatus.failure,
          detail: state.detail,
          message: 'Hãy giữ ít nhất một địa điểm và không trùng lặp.',
        ),
      );
      return;
    }
    await updateStops(
      ItineraryStops.reorder(ItineraryStops.current(detail), ids),
      removalReasons: removalReasons,
    );
  }

  /// Changes the transport of the leg that reaches [toPoiId].
  Future<void> changeLegMode({
    required int toPoiId,
    required TransportMode mode,
  }) async {
    final detail = state.detail;
    if (detail == null) return;
    await updateStops(
      ItineraryStops.withLegMode(
        ItineraryStops.current(detail),
        toPoiId: toPoiId,
        mode: mode,
      ),
    );
  }

  /// Adds a place (typically a restaurant) right after [afterPoiId].
  Future<void> insertStop({
    required int afterPoiId,
    required int poiId,
    required String poiName,
  }) async {
    final detail = state.detail;
    if (detail == null) return;
    await updateStops(
      ItineraryStops.insertAfter(
        ItineraryStops.current(detail),
        afterPoiId: afterPoiId,
        poiId: poiId,
      ),
      newPlaceNames: {poiId: poiName},
    );
  }

  Future<void> replaceStop({
    required int oldPoiId,
    required int newPoiId,
    required String poiName,
  }) async {
    final detail = state.detail;
    if (detail == null) return;
    await updateStops(
      ItineraryStops.replace(
        ItineraryStops.current(detail),
        oldPoiId: oldPoiId,
        newPoiId: newPoiId,
      ),
      newPlaceNames: {newPoiId: poiName},
    );
  }

  Future<void> removeStop(int poiId, StopRemovalReason reason) async {
    final detail = state.detail;
    if (detail == null) return;
    final stops = ItineraryStops.remove(ItineraryStops.current(detail), poiId);
    if (stops.isEmpty) return;
    await updateStops(stops, removalReasons: {poiId: reason});
  }

  /// Re-sends the stops from before the last edit.
  Future<void> undo() async {
    if (isClosed) return;
    final previous = state.undoStops;
    if (previous == null) return;
    await updateStops(previous, isUndo: true);
  }

  /// Saves exactly these stops as a new version. [newPlaceNames] names places
  /// that are not in the itinerary yet, for a "does not fit" message.
  /// [removalReasons] tells, by POI ID, why a stop was left out; it is not
  /// part of the operation key, which identifies the stops only.
  Future<void> updateStops(
    List<ItineraryStop> stops, {
    Map<int, String> newPlaceNames = const {},
    Map<int, StopRemovalReason> removalReasons = const {},
    bool isUndo = false,
  }) async {
    if (isClosed) return;
    final itineraryId = _itineraryId;
    final before = state.detail;
    if (itineraryId == null ||
        before == null ||
        !before.canEdit ||
        state.isBusy ||
        stops.isEmpty) {
      return;
    }
    final pending = List<ItineraryStop>.unmodifiable(stops);
    final key = _keyFor(
      'stops:${pending.map((stop) => '${stop.poiId}/${stop.transportModeToNext?.name}').join(',')}',
    );
    emit(
      ItineraryDetailState(
        status: ItineraryDetailStatus.actionInProgress,
        detail: before,
        pendingStops: pending,
        shiftedArrivals: state.shiftedArrivals,
        undoStops: state.undoStops,
        editRevision: state.editRevision,
      ),
    );
    try {
      final detail = await _repository.updateStops(
        itineraryId: itineraryId,
        stops: pending,
        idempotencyKey: key,
        removalReasons: removalReasons,
      );
      if (isClosed) return;
      _itineraryId = detail.itineraryId;
      _cancelExplanationRefresh();
      _resetOperation();
      emit(
        ItineraryDetailState(
          status: ItineraryDetailStatus.loaded,
          detail: detail,
          shiftedArrivals: ItineraryStops.arrivalShifts(before, detail),
          undoStops: isUndo ? null : ItineraryStops.current(before),
          editRevision: state.editRevision + 1,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          ItineraryDetailState(
            status: ItineraryDetailStatus.failure,
            detail: before,
            pendingStops: pending,
            shiftedArrivals: state.shiftedArrivals,
            // The previous successful edit can still be undone.
            undoStops: state.undoStops,
            editRevision: state.editRevision,
            message: error is StopInfeasibleFailure
                ? _stopMessage(error, before, newPlaceNames)
                : _message(error),
          ),
        );
      }
    }
  }

  String _stopMessage(
    StopInfeasibleFailure failure,
    ItineraryDetail detail,
    Map<int, String> newPlaceNames,
  ) {
    String? name = newPlaceNames[failure.poiId];
    for (final item in detail.visitItems) {
      if (name == null && item.poiId == failure.poiId) name = item.poiName;
    }
    final reason = unfitReasonText(
      failure.reason,
      closesAt: failure.closesAt,
      overflowMinutes: failure.overflowMinutes,
      overflowVnd: failure.overflowVnd,
    );
    if (name == null && failure.reason == 'ExceedsEndTime') {
      return 'Không thể lưu: lịch trình $reason.';
    }
    return 'Không thể lưu: ${name ?? 'Một địa điểm'} $reason.';
  }

  String _keyFor(String fingerprint) {
    if (_operationFingerprint != fingerprint) {
      _operationFingerprint = fingerprint;
      _operationKey = _operationKeyFactory();
    }
    return _operationKey!;
  }

  void _resetOperation() {
    _operationKey = null;
    _operationFingerprint = null;
  }

  ItineraryDetailState _failure(Object error) => ItineraryDetailState(
    status: ItineraryDetailStatus.failure,
    detail: state.detail,
    message: _message(error),
  );

  ItineraryDetailState _loadFailure(Object error) => ItineraryDetailState(
    status: ItineraryDetailStatus.failure,
    detail: error is PermissionFailure || error is NotFoundFailure
        ? null
        : state.detail,
    message: _loadMessage(error),
  );

  String _loadMessage(Object error) => switch (error) {
    AuthenticationFailure() =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    PermissionFailure() => 'Bạn không có quyền xem lịch trình này.',
    NotFoundFailure() => 'Không tìm thấy lịch trình này.',
    _ => 'TripMate chưa tải được lịch trình. Vui lòng thử lại.',
  };

  String _message(Object error) => switch (error) {
    AuthenticationFailure() =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    PermissionFailure() =>
      'Bạn chỉ được xem, không thể thay đổi lịch trình này.',
    NotFoundFailure() => 'Lịch trình này không còn khả dụng.',
    ConflictFailure() =>
      'Thay đổi này trùng với một yêu cầu trước đó. Vui lòng thử lại.',
    ConstraintFailure failure => failure.message,
    ValidationFailure failure => failure.message,
    _ => 'TripMate chưa cập nhật được lịch trình. Vui lòng thử lại.',
  };

  static String _createUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
