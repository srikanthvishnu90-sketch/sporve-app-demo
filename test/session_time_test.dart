import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/utils/session_time.dart';

/// Regression tests for the date-shift bug (#1) that Home "Coming Up" (#3) and
/// the booking weekday (#2) all depend on.
///
/// The bug: sessions store the day at UTC midnight (e.g. 2026-06-20T00:00:00Z)
/// with the clock time in a separate `startTime` string. The old parser called
/// `.toLocal()`, so in any timezone behind UTC the day rolled back to the 19th.
/// These tests assert the CALENDAR DAY is preserved regardless of the machine's
/// timezone — which is only true once `.toLocal()` is removed.
void main() {
  group('parseSessionStart preserves the calendar day', () {
    test('UTC-midnight date + PM time keeps the same day (the exact bug case)', () {
      final dt = parseSessionStart({
        'startDate': '2026-06-20T00:00:00.000Z',
        'startTime': '05:00 PM',
      });
      // With the old .toLocal() in a sub-UTC zone this would be the 19th.
      expect(dt.year, 2026);
      expect(dt.month, 6);
      expect(dt.day, 20);
      expect(dt.hour, 17); // 05:00 PM
      expect(dt.minute, 0);
    });

    test('returned day matches the stored UTC day (timezone-independent)', () {
      const iso = '2026-06-20T00:00:00.000Z';
      final dt = parseSessionStart({'startDate': iso, 'startTime': '05:00 PM'});
      expect(dt.day, DateTime.parse(iso).day); // both 20, never 19
    });

    test('"date" field + AM time also works', () {
      final dt = parseSessionStart({
        'date': '2026-01-01T00:00:00.000Z',
        'startTime': '09:30 AM',
      });
      expect(dt.year, 2026);
      expect(dt.month, 1);
      expect(dt.day, 1);
      expect(dt.hour, 9);
      expect(dt.minute, 30);
    });

    test('12 AM / 12 PM edge cases', () {
      final am = parseSessionStart({'startDate': '2026-06-20T00:00:00.000Z', 'startTime': '12:00 AM'});
      final pm = parseSessionStart({'startDate': '2026-06-20T00:00:00.000Z', 'startTime': '12:00 PM'});
      expect(am.hour, 0);
      expect(pm.hour, 12);
      expect(am.day, 20);
      expect(pm.day, 20);
    });

    test('missing startTime falls back to a clean date on the correct day', () {
      final dt = parseSessionStart({'startDate': '2026-06-20T00:00:00.000Z'});
      expect(dt.day, 20);
      expect(dt.hour, 0);
      expect(dt.minute, 0);
    });

    test('null session does not throw', () {
      expect(() => parseSessionStart(null), returnsNormally);
    });
  });

  group('formatTime12h', () {
    test('formats 24h DateTime to 12h string', () {
      expect(formatTime12h(DateTime(2026, 6, 20, 17, 0)), '5:00 PM');
      expect(formatTime12h(DateTime(2026, 6, 20, 0, 5)), '12:05 AM');
      expect(formatTime12h(DateTime(2026, 6, 20, 12, 30)), '12:30 PM');
    });
  });
}
