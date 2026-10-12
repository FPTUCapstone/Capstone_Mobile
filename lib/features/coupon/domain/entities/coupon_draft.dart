enum CouponDiscountType { percentage, flat }

final class CouponDraft {
  const CouponDraft({
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    required this.minOrderAmount,
    this.usageLimit,
    this.usageLimitPerUser,
    required this.validFromUtc,
    required this.validToUtc,
    required this.applicableTourIds,
  });

  final String code;
  final CouponDiscountType discountType;
  final num discountValue;
  final num? maxDiscountAmount;
  final num minOrderAmount;
  final int? usageLimit;
  final int? usageLimitPerUser;
  final DateTime validFromUtc;
  final DateTime validToUtc;
  final List<int> applicableTourIds;

  Map<String, Object?> toJson() => {
    'code': code.trim().toUpperCase(),
    'discountType': discountType == CouponDiscountType.percentage
        ? 'Percentage'
        : 'Flat',
    'discountValue': discountValue,
    if (discountType == CouponDiscountType.percentage)
      'maxDiscountAmount': maxDiscountAmount,
    'minOrderAmount': minOrderAmount,
    'usageLimit': usageLimit,
    'usageLimitPerUser': usageLimitPerUser,
    'validFromUtc': validFromUtc.toUtc().toIso8601String(),
    'validToUtc': validToUtc.toUtc().toIso8601String(),
    'applicableTourIds': applicableTourIds,
  };
}
