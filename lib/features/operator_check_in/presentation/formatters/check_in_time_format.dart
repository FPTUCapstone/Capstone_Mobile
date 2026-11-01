import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';

/// UC-43 wall-clock presentation in Vietnam (UTC+7), independent of the device.
abstract final class CheckInTimeFormat {
  static String dateTime(DateTime value) {
    final local = tripLocalTime(value);
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${tripClock(value)}';
  }
}
