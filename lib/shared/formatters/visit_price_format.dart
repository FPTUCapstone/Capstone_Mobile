import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';

/// Per-person price text shared by POI and itinerary screens (Review 2, D1).
/// An unknown price is never shown as free.
String visitPriceLabel(double? cost, CostKind? kind) {
  if (cost == null) return 'Chưa có thông tin';
  if (cost <= 0) return 'Miễn phí';
  final prefix = kind == CostKind.averageSpend
      ? 'Mức chi tiêu dự kiến'
      : 'Giá vé dự kiến';
  return '$prefix: ${formatVnd(cost)}/người';
}

/// "1.250.000 VNĐ" (Vietnamese thousands separator). The single money format
/// of the itinerary screens.
String formatVnd(num amount) {
  final digits = amount.round().abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  final offset = digits.length % 3;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (i - offset) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '$buffer VNĐ';
}
