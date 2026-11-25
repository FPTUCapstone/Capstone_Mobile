import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

/// Vietnamese wording for itinerary titles, legs, and feasibility (Review 2).

final _genericGeneratedTitlePattern = RegExp(
  r'^Generated itinerary(?:\s*-\s*.+)?$',
  caseSensitive: false,
);

/// Replaces raw backend boilerplate (`Generated itinerary - 25 Nov 2026`) with
/// a scannable stop-based title while keeping custom titles verbatim.
String formatTripDisplayTitle({
  String? title,
  List<String> previewStopNames = const [],
  DateTime? validFrom,
  String fallback = 'Lịch trình chưa đặt tên',
}) {
  final trimmed = title?.trim();
  final isGeneric =
      trimmed != null && _genericGeneratedTitlePattern.hasMatch(trimmed);
  if (trimmed != null && trimmed.isNotEmpty && !isGeneric) {
    return trimmed;
  }

  final stops = previewStopNames
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .take(3)
      .toList(growable: false);
  if (stops.length >= 2) {
    return '${stops[0]} – ${stops[1]}';
  }
  if (stops.length == 1) {
    return 'Hành trình ${stops[0]}';
  }

  if (validFrom != null) {
    final vn = tripLocalTime(validFrom);
    final dd = vn.day.toString().padLeft(2, '0');
    final mm = vn.month.toString().padLeft(2, '0');
    return 'Lịch trình $dd/$mm';
  }

  return fallback;
}

/// Formats `Stop A → Stop B → Stop C → +2 điểm`, or null if no stop names exist.
String? formatRoutePreview(List<String> previewStopNames, int stopCount) {
  final stops = previewStopNames
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .take(3)
      .toList(growable: false);
  if (stops.isEmpty) return null;
  final remaining = stopCount > stops.length
      ? ' → +${stopCount - stops.length} điểm'
      : '';
  return '${stops.join(' → ')}$remaining';
}

/// Compact weekday label for calendar stubs (`TH 2`..`CN`) in Vietnam time.
String vietnameseWeekdayStub(DateTime utc) {
  final vn = tripLocalTime(utc);
  return switch (vn.weekday) {
    DateTime.monday => 'TH 2',
    DateTime.tuesday => 'TH 3',
    DateTime.wednesday => 'TH 4',
    DateTime.thursday => 'TH 5',
    DateTime.friday => 'TH 6',
    DateTime.saturday => 'TH 7',
    DateTime.sunday => 'CN',
    _ => '',
  };
}

/// Compact Vietnamese date badge (`Thứ 4, 25/11`) in Vietnam time.
String vietnameseShortDate(DateTime utc) {
  final vn = tripLocalTime(utc);
  final weekday = switch (vn.weekday) {
    DateTime.monday => 'Thứ 2',
    DateTime.tuesday => 'Thứ 3',
    DateTime.wednesday => 'Thứ 4',
    DateTime.thursday => 'Thứ 5',
    DateTime.friday => 'Thứ 6',
    DateTime.saturday => 'Thứ 7',
    DateTime.sunday => 'CN',
    _ => '',
  };
  final dd = vn.day.toString().padLeft(2, '0');
  final mm = vn.month.toString().padLeft(2, '0');
  return '$weekday, $dd/$mm';
}

/// Compact Vietnamese duration (`7g 54p`, `8g`, `45p`).
String vietnameseCompactDuration(int minutes) {
  final value = minutes.abs();
  final hours = value ~/ 60;
  final rest = value % 60;
  if (hours == 0) return '${rest}p';
  if (rest == 0) return '${hours}g';
  return '${hours}g ${rest}p';
}

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

/// UC-10: the sentence a visit stop shows. The AI sentence
/// ([friendlyExplanation]) when it has text, else the recommendation reason;
/// never both. Whitespace-only text counts as empty, so a blank AI sentence
/// cannot hide the reason.
String? stopExplanationText({
  String? friendlyExplanation,
  String? recommendationReason,
}) {
  final friendly = friendlyExplanation?.trim();
  if (friendly != null && friendly.isNotEmpty) return friendly;
  final reason = recommendationReason?.trim();
  return reason == null || reason.isEmpty ? null : reason;
}
