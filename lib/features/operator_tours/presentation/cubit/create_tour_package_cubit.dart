import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/load_tour_package_options_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';
import 'package:uuid/uuid.dart';

final class CreateTourPackageCubit extends Cubit<CreateTourPackageState> {
  CreateTourPackageCubit({
    required CreateTourPackageUseCase createTour,
    required LoadTourPackageOptionsUseCase loadOptions,
  }) : _createTour = createTour,
       _loadOptions = loadOptions,
       super(const CreateTourPackageState());
  final CreateTourPackageUseCase _createTour;
  final LoadTourPackageOptionsUseCase _loadOptions;
  String? _pendingIdempotencyKey;
  String? _pendingPayload;

  /// Loads the destination and cancellation-policy catalogues. Safe to retry.
  Future<void> loadOptions() async {
    emit(
      state.copyWith(
        optionsStatus: TourPackageOptionsStatus.loading,
        clearOptionsFailure: true,
      ),
    );
    try {
      final options = await _loadOptions();
      if (!isClosed) {
        emit(
          state.copyWith(
            optionsStatus: TourPackageOptionsStatus.ready,
            options: options,
          ),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            optionsStatus: TourPackageOptionsStatus.failure,
            optionsFailure: failure,
          ),
        );
      }
    }
  }

  Future<void> submit(TourPackageDraft draft) async {
    if (state.status == CreateTourPackageStatus.submitting) return;
    emit(
      state.copyWith(
        status: CreateTourPackageStatus.submitting,
        clearFailure: true,
      ),
    );
    try {
      // The same payload retried after a failed/lost response reuses its key, so the
      // server replays the original draft; any edit starts a new operation.
      final payload = jsonEncode(draft.toJson());
      if (_pendingPayload != payload) {
        _pendingPayload = payload;
        _pendingIdempotencyKey = const Uuid().v4();
      }
      final id = await _createTour(draft, _pendingIdempotencyKey!);
      _pendingIdempotencyKey = null;
      _pendingPayload = null;
      if (!isClosed) {
        emit(
          state.copyWith(status: CreateTourPackageStatus.success, tourId: id),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: CreateTourPackageStatus.failure,
            failure: failure,
          ),
        );
      }
    }
  }
}
