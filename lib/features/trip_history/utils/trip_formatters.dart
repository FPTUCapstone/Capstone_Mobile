import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

abstract final class TripFormatters {
  /// CR-07: Every date is displayed in the dd/MM/yyyy format in the
  /// Asia/Ho_Chi_Minh time zone (UTC+7).
  static String formatVietnamDate(DateTime dateTime) {
    final vnTime = dateTime.isUtc
        ? dateTime.add(const Duration(hours: 7))
        : dateTime.toUtc().add(const Duration(hours: 7));
    final day = vnTime.day.toString().padLeft(2, '0');
    final month = vnTime.month.toString().padLeft(2, '0');
    final year = vnTime.year.toString();
    return '$day/$month/$year';
  }

  /// CR-07: Converts any DateTime to a Vietnam (UTC+7) calendar day.
  /// Returns a UTC DateTime with time component set to 00:00:00 for stable calendar-day comparison.
  static DateTime toVietnamCalendarDay(DateTime dateTime) {
    final vnTime = dateTime.isUtc
        ? dateTime.add(const Duration(hours: 7))
        : dateTime.toUtc().add(const Duration(hours: 7));
    return DateTime.utc(vnTime.year, vnTime.month, vnTime.day);
  }

  /// CR-07 / F-01: Converts a user-selected civil date (from DatePicker) to a canonical UTC calendar day.
  /// Preserves the calendar year, month, and day regardless of local machine timezone offset.
  static DateTime toCivilCalendarDay(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// Formats currency amount in Vietnamese Dong (VND).
  static String formatVnd(int amount) {
    if (amount == 0) return TripHistoryStringsEn.labelFree;

    final s = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(s[i]);
    }
    return '${buffer.toString()} VND';
  }

  /// Alias for formatting currency amount in VND.
  static String formatCurrencyVnd(int amount) => formatVnd(amount);
}
