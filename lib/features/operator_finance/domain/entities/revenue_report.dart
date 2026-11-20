final class RevenueSummary {
  const RevenueSummary({
    required this.grossRevenue,
    required this.paymentsReceived,
    required this.discountsGiven,
    required this.refundedAmount,
    required this.netSales,
    required this.platformCommission,
    required this.netAmount,
    required this.totalBookings,
    required this.totalParticipants,
    required this.commissionRatePercent,
  });

  final num grossRevenue;
  final num paymentsReceived;
  final num discountsGiven;
  final num refundedAmount;
  final num netSales;
  final num platformCommission;

  /// Realised settled payouts less confirmed operator returns, provided by BE.
  final num netAmount;
  final int totalBookings;
  final int totalParticipants;
  final num commissionRatePercent;
}

final class RevenuePeriod {
  const RevenuePeriod({
    required this.periodKey,
    required this.periodLabel,
    required this.grossRevenue,
    required this.commission,
    required this.netAmount,
    required this.refundedAmount,
    required this.bookingsCount,
  });
  final String periodKey;
  final String periodLabel;
  final num grossRevenue;
  final num commission;
  final num netAmount;
  final num refundedAmount;
  final int bookingsCount;
}

final class TourRevenue {
  const TourRevenue({
    required this.tourId,
    required this.tourCode,
    required this.tourName,
    required this.bookingsCount,
    required this.participantsCount,
    required this.grossRevenue,
    required this.refundedAmount,
    required this.commission,
    required this.netAmount,
  });
  final int tourId;
  final String tourCode;
  final String tourName;
  final int bookingsCount;
  final int participantsCount;
  final num grossRevenue;
  final num refundedAmount;
  final num commission;
  final num netAmount;
}

final class RevenueTourOption {
  const RevenueTourOption({
    required this.id,
    required this.code,
    required this.title,
    required this.isActive,
  });
  final int id;
  final String code;
  final String title;
  final bool isActive;
}

/// All sections and paging metadata form one server snapshot.
final class RevenueReport {
  const RevenueReport({
    required this.summary,
    required this.chartData,
    required this.tourDetails,
    required this.totalToursCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
  final RevenueSummary summary;
  final List<RevenuePeriod> chartData;
  final List<TourRevenue> tourDetails;
  final int totalToursCount;
  final int page;
  final int pageSize;
  final int totalPages;
}
