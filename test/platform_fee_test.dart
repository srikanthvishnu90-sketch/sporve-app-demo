import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/utils/platform_fee.dart';

// Coach OS money page #2 — the per-transaction fee itemization is the SINGLE
// source of truth both the coach and (later) the org/trainer read. These tests
// pin the money math (cents-exact, mirrors the server's
// Math.round((amount*bps)/10000)) and the first-vs-recurring assignment
// (mirrors resolve_platform_fee_bps: per family+coach, earliest paid = intro).
void main() {
  group('feeCentsFor mirrors the server rounding', () {
    test('18% intro on \$80.00', () {
      // 8000 * 1800 / 10000 = 1440
      expect(feeCentsFor(8000, kFirstBookingFeeBps), 1440);
    });
    test('4% recurring on \$80.00', () {
      // 8000 * 400 / 10000 = 320
      expect(feeCentsFor(8000, kRecurringFeeBps), 320);
    });
    test('2.5% off-platform on \$80.00', () {
      // 8000 * 250 / 10000 = 200
      expect(feeCentsFor(8000, kOffPlatformFeeBps), 200);
    });
    test('rounds to nearest cent (banker-free .round())', () {
      // 3333 * 1800 / 10000 = 599.94 -> 600
      expect(feeCentsFor(3333, kFirstBookingFeeBps), 600);
    });
  });

  group('FeeItemization.marketplace gross - fee = net', () {
    test('intro line', () {
      final it = FeeItemization.marketplace(
        bookingId: 'b1',
        grossCents: 8000,
        isFirst: true,
      );
      expect(it.feeBps, kFirstBookingFeeBps);
      expect(it.feeCents, 1440);
      expect(it.netCents, 6560);
      expect(it.gross, 80.0);
      expect(it.ratePct, '18%');
    });
    test('recurring line', () {
      final it = FeeItemization.marketplace(
        bookingId: 'b2',
        grossCents: 8000,
        isFirst: false,
      );
      expect(it.feeCents, 320);
      expect(it.netCents, 7680);
      expect(it.ratePct, '4%');
    });
    test('off-platform SaaS line uses the thin rate + flags', () {
      final it = FeeItemization.offPlatform(bookingId: 'i1', grossCents: 16000);
      expect(it.isOffPlatform, true);
      expect(it.feeCents, 400); // 2.5%
      expect(it.netCents, 15600);
      expect(it.ratePct, '2.5%');
    });
  });

  group('itemizeCoachEarnings — first vs recurring per family', () {
    test('earliest booking per family is the intro rate; rest recurring', () {
      final inputs = [
        // Family A: two bookings — the earlier is intro.
        const FeeInput(
            bookingId: 'a_late',
            familyKey: 'A',
            sortKey: '2026-03-01',
            grossCents: 8000),
        const FeeInput(
            bookingId: 'a_early',
            familyKey: 'A',
            sortKey: '2026-01-01',
            grossCents: 8000),
        // Family B: single booking — intro.
        const FeeInput(
            bookingId: 'b_only',
            familyKey: 'B',
            sortKey: '2026-02-01',
            grossCents: 5000),
      ];
      final out = itemizeCoachEarnings(inputs);
      // Output order matches input order.
      expect(out[0].bookingId, 'a_late');
      expect(out[0].isFirst, false); // later A booking = recurring
      expect(out[0].feeBps, kRecurringFeeBps);
      expect(out[1].bookingId, 'a_early');
      expect(out[1].isFirst, true); // earliest A = intro
      expect(out[1].feeBps, kFirstBookingFeeBps);
      expect(out[2].bookingId, 'b_only');
      expect(out[2].isFirst, true); // only B = intro
    });

    test('a family key is scoped per coach — different families each get intro',
        () {
      final inputs = [
        const FeeInput(
            bookingId: 'x',
            familyKey: 'fam1',
            sortKey: '2026-01-01',
            grossCents: 8000),
        const FeeInput(
            bookingId: 'y',
            familyKey: 'fam2',
            sortKey: '2026-01-02',
            grossCents: 8000),
      ];
      final out = itemizeCoachEarnings(inputs);
      expect(out.every((i) => i.isFirst), true);
    });

    test('deterministic tie-break on bookingId when sortKeys match', () {
      final inputs = [
        const FeeInput(
            bookingId: 'zzz',
            familyKey: 'A',
            sortKey: '2026-01-01',
            grossCents: 8000),
        const FeeInput(
            bookingId: 'aaa',
            familyKey: 'A',
            sortKey: '2026-01-01',
            grossCents: 8000),
      ];
      final out = itemizeCoachEarnings(inputs);
      // 'aaa' < 'zzz' so it wins the intro rate regardless of input order.
      expect(out.firstWhere((i) => i.bookingId == 'aaa').isFirst, true);
      expect(out.firstWhere((i) => i.bookingId == 'zzz').isFirst, false);
    });
  });

  group('totalsOf aggregates cents exactly', () {
    test('sums gross/fee/net across mixed rates', () {
      final items = [
        FeeItemization.marketplace(
            bookingId: 'a', grossCents: 8000, isFirst: true), // fee 1440
        FeeItemization.marketplace(
            bookingId: 'b', grossCents: 8000, isFirst: false), // fee 320
      ];
      final t = totalsOf(items);
      expect(t.count, 2);
      expect(t.grossCents, 16000);
      expect(t.feeCents, 1760);
      expect(t.netCents, 14240);
      expect(t.net, 142.40);
    });
  });
}
