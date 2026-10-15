import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';
import 'package:uuid/uuid.dart';

final class CreateTourPackageCubit extends Cubit<CreateTourPackageState> {
  CreateTourPackageCubit({required CreateTourPackageUseCase createTour})
    : _createTour = createTour,
      super(const CreateTourPackageState());
  final CreateTourPackageUseCase _createTour;
  String? _pendingIdempotencyKey;
  String? _pendingPayload;
  Future<void> submit(TourPackageDraft draft) async {
    emit(
      const CreateTourPackageState(status: CreateTourPackageStatus.submitting),
    );
    try {
      final payload = jsonEncode(draft.toJson());
      if (_pendingPayload != payload) {
        _pendingPayload = payload;
        _pendingIdempotencyKey = Uuid().v4();
      }
      final id = await _createTour(draft, _pendingIdempotencyKey!);
      _pendingIdempotencyKey = null;
      _pendingPayload = null;
      if (!isClosed) {
        emit(
          CreateTourPackageState(
            status: CreateTourPackageStatus.success,
            tourId: id,
          ),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          CreateTourPackageState(
            status: CreateTourPackageStatus.failure,
            failure: failure,
          ),
        );
      }
    }
  }
}
