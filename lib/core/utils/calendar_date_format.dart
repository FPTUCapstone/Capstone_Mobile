/// Formats calendar fields without shifting their time zone. Use this for
/// birthdays/date-picker values; convert instants to their display zone first.
String formatCalendarDate(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year.toString().padLeft(4, '0')}';

/// Replaces only the date of a raw timestamp, retaining its time precision
/// and UTC suffix. Callers keep their existing timezone conversion.
String formatCalendarDateTime(DateTime value) =>
    '${formatCalendarDate(value)}${value.toString().substring(10)}';

String _two(int value) => value.toString().padLeft(2, '0');
