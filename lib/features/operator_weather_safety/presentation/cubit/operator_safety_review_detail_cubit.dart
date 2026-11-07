import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_review_detail_state.dart';

final class OperatorSafetyReviewDetailCubit
    extends Cubit<OperatorSafetyReviewDetailState> {
  OperatorSafetyReviewDetailCubit({
    required int reviewId,
    required GetWeatherSafetyReviewUseCase getReview,
    required AcknowledgeWeatherSafetyReviewUseCase acknowledge,
    required NetworkInfo networkInfo,
    Stream<WeatherSafetyReviewHint>? hints,
  }) : _reviewId = reviewId,
       _getReview = getReview,
       _acknowledge = acknowledge,
       _networkInfo = networkInfo,
       super(const OperatorSafetyReviewDetailState()) {
    _subscriptions.add(
      _networkInfo.onConnectivityChanged.listen((connected) {
        if (connected) {
          unawaited(load());
        } else if (state.review != null) {
          emit(state.copyWith(isStale: true, isOffline: true));
        }
      }),
    );
    if (hints != null) {
      _subscriptions.add(
        hints.where((hint) => hint.reviewId == _reviewId).listen((_) {
          unawaited(load());
        }),
      );
    }
  }

  final int _reviewId;
  final GetWeatherSafetyReviewUseCase _getReview;
  final AcknowledgeWeatherSafetyReviewUseCase _acknowledge;
  final NetworkInfo _networkInfo;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Bumped by every load and finished acknowledgement; a slower response that
  /// started earlier must not overwrite newer state.
  int _latest = 0;

  /// Reloads silently when a review is already on screen. Only a Safe 404
  /// removes it: a transient failure keeps it, labelled as out of date.
  Future<void> load() async {
    final request = ++_latest;
    try {
      final review = await _getReview(_reviewId);
      if (isClosed || request != _latest) return;
      emit(
        OperatorSafetyReviewDetailState(
          status: OperatorSafetyReviewDetailStatus.ready,
          review: review,
          actionFailure: state.actionFailure,
          isAcknowledging: state.isAcknowledging,
        ),
      );
    } on NotFoundFailure {
      if (isClosed || request != _latest) return;
      _emitNotFound();
    } on Failure catch (failure) {
      if (isClosed || request != _latest) return;
      if (state.review != null) {
        emit(
          state.copyWith(isStale: true, isOffline: failure is NetworkFailure),
        );
        return;
      }
      emit(
        OperatorSafetyReviewDetailState(
          status: OperatorSafetyReviewDetailStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  Future<void> acknowledgeReview({String? immediateInstructions}) async {
    final current = state.review;
    if (current == null || !current.canAcknowledge || state.isAcknowledging) {
      return;
    }
    emit(state.copyWith(isAcknowledging: true, clearActionFailure: true));
    if (!await _networkInfo.isConnected) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isAcknowledging: false,
          actionFailure: const NetworkFailure(),
          isStale: true,
          isOffline: true,
        ),
      );
      return;
    }
    final instructions = immediateInstructions?.trim();
    try {
      final updated = await _acknowledge(
        _reviewId,
        immediateInstructions: instructions == null || instructions.isEmpty
            ? null
            : instructions,
      );
      if (isClosed) return;
      _latest++;
      emit(
        OperatorSafetyReviewDetailState(
          status: OperatorSafetyReviewDetailStatus.ready,
          review: updated,
        ),
      );
    } on NotFoundFailure {
      if (isClosed) return;
      _latest++;
      _emitNotFound();
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(state.copyWith(isAcknowledging: false, actionFailure: failure));
      // The rejection may mean the review moved on; show its current state.
      if (failure is EmergencyTourFailure) await load();
    }
  }

  void _emitNotFound() => emit(
    const OperatorSafetyReviewDetailState(
      status: OperatorSafetyReviewDetailStatus.notFound,
    ),
  );

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
