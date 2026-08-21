/// Helpers for turning the app's mock/session data into real [DateTime]s.
///
/// Sessions store the day as an ISO `startDate` (e.g. `2026-05-04T00:00:00Z`)
/// and the clock time as a separate 12-hour string `startTime` (e.g. `05:00 PM`).
/// Calling `DateTime.parse("05:00 PM")` throws `FormatException: Invalid date
/// format`, so these helpers combine the two fields safely.
library;

/// Builds a [DateTime] for a session by combining its `startDate` (ISO) with
/// its `startTime` ("hh:mm AM/PM"). Returns null when either fact is missing or
/// malformed. Callers must render "Time unavailable" instead of guessing.
DateTime? parseSessionStart(dynamic session) {
  if (session is! Map) return null;

  final dateStr = (session['startDate'] ?? session['date'])?.toString();
  // Treat the stored value as a plain CALENDAR DATE — it's a day pinned at UTC
  // midnight. Never call .toLocal(), and never substitute DateTime.now().
  final base = dateStr == null ? null : DateTime.tryParse(dateStr);
  if (base == null) return null;

  final timeStr = session['startTime']?.toString();
  final match = timeStr == null
      ? null
      : RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(timeStr);
  if (match == null) return null;
  var hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || minute > 59 || hour < 1 || hour > 12) {
    return null;
  }
  final period = match.group(3)?.toUpperCase();
  if (period == null) return null;
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return DateTime(base.year, base.month, base.day, hour, minute);
}

/// Formats a [DateTime] as a clean 12-hour clock string, e.g. `5:00 PM`.
String formatTime12h(DateTime? dt) {
  if (dt == null) return 'Time unavailable';
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  var hour = dt.hour % 12;
  if (hour == 0) hour = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}
