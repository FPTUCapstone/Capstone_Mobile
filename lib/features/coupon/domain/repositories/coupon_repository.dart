import 'package:trip_mate_mobile/features/coupon/domain/entities/coupon_draft.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/eligible_coupon_tour.dart';

abstract interface class CouponRepository {
  Future<List<EligibleCouponTour>> getEligibleTours();
  Future<String> createCoupon(CouponDraft draft);
}
