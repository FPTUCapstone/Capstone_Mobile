import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/coupon_draft.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/eligible_coupon_tour.dart';
import 'package:trip_mate_mobile/features/coupon/domain/repositories/coupon_repository.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_cubit.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_state.dart';

void main() {
  final draft = CouponDraft(
    code: 'TRIP10',
    discountType: CouponDiscountType.percentage,
    discountValue: 10,
    maxDiscountAmount: 100000,
    minOrderAmount: 0,
    validFromUtc: DateTime.utc(2026, 10, 5),
    validToUtc: DateTime.utc(2026, 10, 6),
    applicableTourIds: const [1],
  );

  blocTest<CreateCouponCubit, CreateCouponState>(
    'loads only the repository eligible tours before the form is usable',
    build: () => CreateCouponCubit(repository: _CouponRepository()),
    act: (cubit) => cubit.loadTours(),
    expect: () => [
      const CreateCouponState(status: CreateCouponStatus.loadingTours),
      const CreateCouponState(
        status: CreateCouponStatus.ready,
        tours: [
          EligibleCouponTour(
            id: 1,
            title: 'Da Nang',
            destination: 'Da Nang',
            basePrice: 500000,
          ),
        ],
      ),
    ],
  );

  blocTest<CreateCouponCubit, CreateCouponState>(
    'keeps a safe failure message when creation is rejected',
    build: () => CreateCouponCubit(
      repository: _CouponRepository(failure: const PermissionFailure()),
    ),
    act: (cubit) => cubit.create(draft),
    expect: () => [
      const CreateCouponState(status: CreateCouponStatus.submitting),
      const CreateCouponState(
        status: CreateCouponStatus.submissionFailure,
        failure: PermissionFailure(),
      ),
    ],
  );
}

final class _CouponRepository implements CouponRepository {
  _CouponRepository({this.failure});
  final Failure? failure;

  @override
  Future<String> createCoupon(CouponDraft draft) async {
    if (failure != null) throw failure!;
    return 'TRIP10';
  }

  @override
  Future<List<EligibleCouponTour>> getEligibleTours() async => const [
    EligibleCouponTour(
      id: 1,
      title: 'Da Nang',
      destination: 'Da Nang',
      basePrice: 500000,
    ),
  ];
}
