import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_cancellation_rule.dart';

/// "2,890,000 VND".
String formatVnd(int price) {
  final text = price.toString();
  final buffer = StringBuffer();
  final length = text.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  buffer.write(' VND');
  return buffer.toString();
}

String _two(int value) => value.toString().padLeft(2, '0');

/// "06/11/2026" in Vietnam time, whatever the device zone.
String formatVietnamDate(DateTime value) {
  final local = tripLocalTime(value);
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

/// "06/11/2026 08:00" in Vietnam time.
String formatVietnamDateTime(DateTime value) =>
    '${formatVietnamDate(value)} ${tripClock(value)}';

/// Departure window in Vietnam time: "06/11/2026 08:00 – 17:00" for one day,
/// "06/11/2026 08:00 – 08/11/2026 17:00" across days.
String formatDepartureWindow(DateTime start, DateTime? end) {
  final from = formatVietnamDateTime(start);
  if (end == null) return from;
  if (sameTripDay(start, end)) return '$from – ${tripClock(end)}';
  return '$from – ${formatVietnamDateTime(end)}';
}

String _days(int days) => '$days ngày';

String _fee(double percent) {
  if (percent == 0) return 'miễn phí';
  final text = percent == percent.truncateToDouble()
      ? percent.toInt().toString()
      : percent.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return 'phí $text%';
}

/// One line per rule. A rule applies from its notice period down to the next
/// shorter rule (the Backend copies the operator's template: for example
/// 30 → free, 15 → 25 %, 7 → 50 %, 0 → 100 %). Order of [rules] does not matter.
List<String> describeCancellationRules(List<TourCancellationRule> rules) {
  final ordered = [...rules]
    ..sort((a, b) => b.daysBeforeDeparture - a.daysBeforeDeparture);
  final lines = <String>[];
  for (var i = 0; i < ordered.length; i++) {
    final days = ordered[i].daysBeforeDeparture;
    final fee = _fee(ordered[i].feePercent);
    if (i == 0) {
      lines.add(
        days == 0
            ? 'Hủy bất kỳ lúc nào: $fee'
            : 'Hủy từ $days ngày trở lên trước khởi hành: $fee',
      );
      continue;
    }
    final previous = ordered[i - 1].daysBeforeDeparture;
    if (days == 0) {
      lines.add('Hủy dưới ${_days(previous)} trước khởi hành: $fee');
      continue;
    }
    final upper = previous - 1;
    lines.add(
      upper <= days
          ? 'Hủy đúng ${_days(days)} trước khởi hành: $fee'
          : 'Hủy từ $days đến $upper ngày trước khởi hành: $fee',
    );
  }
  return lines;
}
