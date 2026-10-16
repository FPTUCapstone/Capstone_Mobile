import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

/// Vietnamese wording for itinerary legs and feasibility (Review 2).

/// "45 phút", "1 giờ", "1 giờ 20 phút".
String vietnameseDuration(int minutes) {
  final value = minutes.abs();
  final hours = value ~/ 60;
  final rest = value % 60;
  if (hours == 0) return '$rest phút';
  if (rest == 0) return '$hours giờ';
  return '$hours giờ $rest phút';
}

/// "850 m" below 1 km, otherwise "9,4 km".
String formatLegDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = (meters / 100).round() / 10;
  final text = km == km.roundToDouble()
      ? km.toStringAsFixed(0)
      : km.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')} km';
}

String transportLabel(TransportMode mode) => switch (mode) {
  TransportMode.walking => 'Đi bộ',
  TransportMode.motorbike => 'Xe máy',
  TransportMode.car => 'Ô tô/taxi',
  TransportMode.publicTransit => 'Phương tiện công cộng',
};

/// Average walking pace used for the "close enough to walk" hint.
const walkingMetersPerMinute = 80;

/// Minutes to walk [meters], at least one.
int walkingMinutes(int meters) {
  final minutes = (meters / walkingMetersPerMinute).ceil();
  return minutes < 1 ? 1 : minutes;
}

/// Why a stop does not fit, e.g. "vượt giờ kết thúc 1 giờ 20 phút".
String unfitReasonText(
  String? reason, {
  String? closesAt,
  int? overflowMinutes,
  double? overflowVnd,
}) => switch (reason) {
  'ClosedAtArrival' =>
    closesAt == null
        ? 'đã đóng cửa khi đến nơi'
        : 'đã đóng cửa khi đến nơi (đóng cửa lúc $closesAt)',
  'ExceedsEndTime' =>
    overflowMinutes == null
        ? 'vượt giờ kết thúc'
        : 'vượt giờ kết thúc ${vietnameseDuration(overflowMinutes)}',
  'ExceedsBudget' =>
    overflowVnd == null
        ? 'vượt ngân sách'
        : 'vượt ngân sách ${formatVnd(overflowVnd)}',
  'OutsideRadius' => 'nằm ngoài bán kính khám phá',
  'Inactive' => 'hiện không hoạt động',
  'NoOpeningHours' => 'chưa có giờ mở cửa',
  _ => 'không phù hợp với lịch trình',
};

/// Capitalises the first letter of a reason used on its own.
String capitalized(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
