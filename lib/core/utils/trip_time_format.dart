/// Itinerary times are planned and shown in Vietnam time (UTC+7), whatever the
/// device time zone. A trip is one continuous window that may cross midnight,
/// so a time on a later day than the trip start carries its date.
library;

/// Vietnam is UTC+7 all year (no daylight saving).
const vietnamOffset = Duration(hours: 7);
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Wall-clock Vietnam time of [value] (returned as a UTC-tagged value).
DateTime tripLocalTime(DateTime value) => value.toUtc().add(vietnamOffset);

/// "HH:mm" in Vietnam time.
String tripClock(DateTime value) {
  final local = tripLocalTime(value);
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// "Thu, 15 Oct" in Vietnam time.
String tripDate(DateTime value) {
  final local = tripLocalTime(value);
  return '${_weekdays[local.weekday - 1]}, ${local.day} '
      '${_months[local.month - 1]}';
}

/// Whether [a] and [b] fall on the same Vietnam calendar day.
bool sameTripDay(DateTime a, DateTime b) {
  final left = tripLocalTime(a);
  final right = tripLocalTime(b);
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

/// "HH:mm", or "Fri, 16 Oct HH:mm" when [value] falls on a later day than
/// [tripStart].
String tripTimeLabel(DateTime value, {DateTime? tripStart}) {
  if (tripStart == null || sameTripDay(value, tripStart)) {
    return tripClock(value);
  }
  return '${tripDate(value)} ${tripClock(value)}';
}

/// "Thu, 15 Oct · 18:42–22:27" for a same-day trip, or
/// "Thu, 15 Oct 18:42 – Fri, 16 Oct 02:30" when it crosses midnight.
String? tripSchedule(DateTime? from, DateTime? to) {
  if (from == null) return null;
  if (to == null) return '${tripDate(from)} · ${tripClock(from)}';
  if (sameTripDay(from, to)) {
    return '${tripDate(from)} · ${tripClock(from)}–${tripClock(to)}';
  }
  return '${tripDate(from)} ${tripClock(from)} – '
      '${tripDate(to)} ${tripClock(to)}';
}

/// "2 h 15 min", "45 min" or "1 day 2 h" for a duration in minutes.
String tripDuration(int minutes) {
  final days = minutes ~/ (24 * 60);
  final hours = (minutes % (24 * 60)) ~/ 60;
  final remaining = minutes % 60;
  final parts = <String>[
    if (days > 0) '$days ${days == 1 ? 'day' : 'days'}',
    if (hours > 0) '$hours h',
    if (remaining > 0) '$remaining min',
  ];
  return parts.isEmpty ? '0 min' : parts.join(' ');
}
