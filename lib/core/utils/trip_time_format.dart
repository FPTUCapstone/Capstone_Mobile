/// Itinerary times are planned and shown in Vietnam time (UTC+7), whatever the
/// device time zone. A trip is one continuous window that may cross midnight,
/// so a time on a later day than the trip start carries its date.
library;

/// Vietnam is UTC+7 all year (no daylight saving).
const vietnamOffset = Duration(hours: 7);
const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Wall-clock Vietnam time of [value] (returned as a UTC-tagged value).
DateTime tripLocalTime(DateTime value) => value.toUtc().add(vietnamOffset);

/// "HH:mm" in Vietnam time.
String tripClock(DateTime value) {
  final local = tripLocalTime(value);
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// "T5, 15/10" in Vietnam time.
String tripDate(DateTime value) {
  final local = tripLocalTime(value);
  return '${_weekdays[local.weekday - 1]}, '
      '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}';
}

/// Whether [a] and [b] fall on the same Vietnam calendar day.
bool sameTripDay(DateTime a, DateTime b) {
  final left = tripLocalTime(a);
  final right = tripLocalTime(b);
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

/// "HH:mm", or "T6, 16/10 HH:mm" when [value] falls on a later day than
/// [tripStart].
String tripTimeLabel(DateTime value, {DateTime? tripStart}) {
  if (tripStart == null || sameTripDay(value, tripStart)) {
    return tripClock(value);
  }
  return '${tripDate(value)} ${tripClock(value)}';
}

/// "T5, 15/10 · 18:42–22:27" for a same-day trip, or
/// "T5, 15/10 18:42 – T6, 16/10 02:30" when it crosses midnight.
String? tripSchedule(DateTime? from, DateTime? to) {
  if (from == null) return null;
  if (to == null) return '${tripDate(from)} · ${tripClock(from)}';
  if (sameTripDay(from, to)) {
    return '${tripDate(from)} · ${tripClock(from)}–${tripClock(to)}';
  }
  return '${tripDate(from)} ${tripClock(from)} – '
      '${tripDate(to)} ${tripClock(to)}';
}

/// "2 giờ 15 phút", "45 phút" or "1 ngày 2 giờ" for a duration in minutes.
String tripDuration(int minutes) {
  final days = minutes ~/ (24 * 60);
  final hours = (minutes % (24 * 60)) ~/ 60;
  final remaining = minutes % 60;
  final parts = <String>[
    if (days > 0) '$days ngày',
    if (hours > 0) '$hours giờ',
    if (remaining > 0) '$remaining phút',
  ];
  return parts.isEmpty ? '0 phút' : parts.join(' ');
}
