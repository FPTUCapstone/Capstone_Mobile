import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/coupon_draft.dart';
import 'package:trip_mate_mobile/features/coupon/domain/repositories/coupon_repository.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_state.dart';

final class CreateCouponCubit extends Cubit<CreateCouponState> {
  CreateCouponCubit({required CouponRepository repository})
    : _repository = repository,
      super(const CreateCouponState());
  final CouponRepository _repository;
  int _epoch = 0;

  Future<void> loadTours() async {
    final epoch = ++_epoch;
    emit(
      state.copyWith(
        status: CreateCouponStatus.loadingTours,
        clearFailure: true,
      ),
    );
    try {
      final tours = await _repository.getEligibleTours();
      if (isClosed || epoch != _epoch) return;
      emit(
        state.copyWith(
          status: CreateCouponStatus.ready,
          tours: tours,
          clearFailure: true,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed || epoch != _epoch) return;
      emit(
        state.copyWith(
          status: CreateCouponStatus.tourLoadFailure,
          failure: failure,
        ),
      );
    }
  }

  Future<void> create(CouponDraft draft) async {
    final epoch = ++_epoch;
    emit(
      state.copyWith(status: CreateCouponStatus.submitting, clearFailure: true),
    );
    try {
      final code = await _repository.createCoupon(draft);
      if (isClosed || epoch != _epoch) return;
      emit(
        state.copyWith(
          status: CreateCouponStatus.success,
          createdCode: code,
          clearFailure: true,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed || epoch != _epoch) return;
      emit(
        state.copyWith(
          status: CreateCouponStatus.submissionFailure,
          failure: failure,
        ),
      );
    }
  }

  void prepareNextCoupon() {
    if (isClosed) return;
    _epoch++;
    emit(
      state.copyWith(
        status: CreateCouponStatus.ready,
        clearFailure: true,
        clearCreatedCode: true,
      ),
    );
  }
}
