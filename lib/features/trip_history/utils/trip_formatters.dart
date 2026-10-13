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
}
