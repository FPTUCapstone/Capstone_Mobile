import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/coupon/data/datasources/coupon_remote_data_source.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/coupon_draft.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/eligible_coupon_tour.dart';
import 'package:trip_mate_mobile/features/coupon/domain/repositories/coupon_repository.dart';

final class CouponRepositoryImpl implements CouponRepository {
  const CouponRepositoryImpl(this._remote);
  final CouponRemoteDataSource _remote;

  @override
  Future<List<EligibleCouponTour>> getEligibleTours() async {
    try {
      return await _remote.getEligibleTours();
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<String> createCoupon(CouponDraft draft) async {
    try {
      return await _remote.createCoupon(draft);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
