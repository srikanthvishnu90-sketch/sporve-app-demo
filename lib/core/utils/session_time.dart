/// Helpers for turning the app's mock/session data into real [DateTime]s.
///
/// Sessions store the day as an ISO `startDate` (e.g. `2026-05-04T00:00:00Z`)
/// and the clock time as a separate 12-hour string `startTime` (e.g. `05:00 PM`).
/// Calling `DateTime.parse("05:00 PM")` throws `FormatException: Invalid date
/// format`, so these helpers combine the two fields safely.
library;

/// Builds a [DateTime] for a session by combining its `startDate` (ISO) with
/// its `startTime` ("hh:mm AM/PM"). Falls back gracefully to now if data is
/// missing or malformed, so the UI never crashes on bad mock data.
DateTime parseSessionStart(dynamic session) {
  if (session == null) return DateTime.now();

  DateTime base;
  final dateStr = (session['startDate'] ?? session['date'])?.toString();
  try {
    // Treat the stored value as a plain CALENDAR DATE — it's a day pinned at
    // UTC midnight (e.g. 2026-06-20T00:00:00Z). We must NOT call .toLocal()
    // here: in any timezone behind UTC that shifts the day backward (midnight
    // becomes the previous evening), filing every session on the wrong day.
    // The real clock time is applied from `startTime` below.
    base = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
  } catch (_) {
    base = DateTime.now();
  }

  final timeStr = session['startTime']?.toString();
  final match = timeStr == null
      ? null
      : RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(timeStr);
  if (match != null) {
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  // No usable startTime — return a clean, tz-free local-naive date on the
  // correct calendar day so year/month/day grouping stays accurate.
  return DateTime(base.year, base.month, base.day);
}

/// Formats a [DateTime] as a clean 12-hour clock string, e.g. `5:00 PM`.
String formatTime12h(DateTime dt) {
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  var hour = dt.hour % 12;
  if (hour == 0) hour = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}
