import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_state.dart';

final class ItineraryDetailCubit extends Cubit<ItineraryDetailState> {
  ItineraryDetailCubit({
    required ItineraryRepository repository,
    String Function()? operationKeyFactory,
  }) : _repository = repository,
       _operationKeyFactory = operationKeyFactory ?? _createUuidV4,
       super(const ItineraryDetailState.initial());

  final ItineraryRepository _repository;
  final String Function() _operationKeyFactory;
  int? _itineraryId;
  String? _operationKey;
  String? _operationFingerprint;

  Future<void> load(int itineraryId) async {
    if (itineraryId <= 0) {
      emit(
        const ItineraryDetailState(
          status: ItineraryDetailStatus.failure,
          message: 'This itinerary is unavailable.',
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
    } catch (error) {
      if (isClosed) return;
      emit(_loadFailure(error));
    }
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

  Future<void> adjustItems(List<int> orderedVisitPoiIds) async {
    final itineraryId = _itineraryId;
    if (itineraryId == null ||
        state.detail?.canManage != true ||
        state.isBusy) {
      return;
    }
    final ids = List<int>.unmodifiable(orderedVisitPoiIds);
    if (ids.isEmpty || ids.toSet().length != ids.length) {
      emit(
        ItineraryDetailState(
          status: ItineraryDetailStatus.failure,
          detail: state.detail,
          message: 'Select at least one different location.',
        ),
      );
      return;
    }
    final key = _keyFor('adjust:${ids.join(',')}');
    emit(
      ItineraryDetailState(
        status: ItineraryDetailStatus.actionInProgress,
        detail: state.detail,
        editingPoiIds: ids,
      ),
    );
    try {
      final detail = await _repository.adjustItems(
        itineraryId: itineraryId,
        orderedVisitPoiIds: ids,
        idempotencyKey: key,
      );
      if (isClosed) return;
      _resetOperation();
      emit(
        ItineraryDetailState(
          status: ItineraryDetailStatus.loaded,
          detail: detail,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          ItineraryDetailState(
            status: ItineraryDetailStatus.failure,
            detail: state.detail,
            editingPoiIds: ids,
            message: _message(error),
          ),
        );
      }
    }
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
      'Your session has expired. Please sign in again.',
    PermissionFailure() => 'You do not have access to this itinerary.',
    NotFoundFailure() => 'This itinerary could not be found.',
    _ => 'TripMate could not load this itinerary. Please try again.',
  };

  String _message(Object error) => switch (error) {
    AuthenticationFailure() =>
      'Your session has expired. Please sign in again.',
    PermissionFailure() => 'You can view this itinerary but cannot change it.',
    NotFoundFailure() => 'This itinerary is no longer available.',
    ConflictFailure() =>
      'This change conflicts with a previous request. Please try again.',
    ConstraintFailure failure => failure.message,
    ValidationFailure failure => failure.message,
    _ => 'TripMate could not update this itinerary. Please try again.',
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
