/// Server-calculated snapshot. Reporting dates are Vietnam calendar dates.
final class OperatorDashboardMetrics {
  const OperatorDashboardMetrics({
    required this.activeTourCount,
    required this.monthlyBookingCount,
    required this.monthlyNetAmount,
    required this.activeCouponCount,
    required this.asOfUtc,
    required this.monthStart,
    required this.monthEndExclusive,
  });

  final int activeTourCount;
  final int monthlyBookingCount;
  final num monthlyNetAmount;
  final int activeCouponCount;
  final DateTime asOfUtc;
  final DateTime monthStart;
  final DateTime monthEndExclusive;
}
