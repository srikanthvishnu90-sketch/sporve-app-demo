import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/utils/commission.dart';
import 'package:flutter_structure/core/utils/platform_fee.dart';

// Provider-Model-Rebuild #5 — the ORG↔TRAINER commission engine.
// These pin the two guarantees the spec + ledger require:
//   1. changing commission NEVER alters a past booking's snapshot (effective-
//      dating + captured snapshot);
//   2. the live-math preview reuses platform_fee.dart VERBATIM, so the org and
//      trainer always see the identical itemization (one shared shape).
void main() {
  group('commissionInEffect — the rate at a point in time', () {
    final rates = [
      CommissionRate(
          type: CommissionType.percent,
          value: 20,
          effectiveFrom: DateTime.utc(2026, 1, 1)),
      CommissionRate(
          type: CommissionType.percent,
          value: 30,
          effectiveFrom: DateTime.utc(2026, 6, 1)),
    ];

    test('picks the latest rate that has already begun', () {
      final r = commissionInEffect(rates, DateTime.utc(2026, 3, 1));
      expect(r!.value, 20);
    });

    test('after the change, the new rate applies going forward', () {
      final r = commissionInEffect(rates, DateTime.utc(2026, 7, 1));
      expect(r!.value, 30);
    });

    test('before any rate begins, none applies (falls back to default)', () {
      final r = commissionInEffect(rates, DateTime.utc(2025, 12, 31));
      expect(r, isNull);
    });
  });

  group('changing commission does NOT alter a past booking snapshot (#5)', () {
    test('a snapshot captured under the old rate is immutable when the rate rises',
        () {
      // A booking placed Feb 1 under a 20% rate.
      final ratesAtBooking = [
        CommissionRate(
            type: CommissionType.percent,
            value: 20,
            effectiveFrom: DateTime.utc(2026, 1, 1)),
      ];
      final snap = CommissionSnapshot.capture(
        bookingId: 'past',
        grossCents: 8000,
        rates: ratesAtBooking,
        at: DateTime.utc(2026, 2, 1),
        isFirst: false,
      );
      // 20% of $80 = $16.00.
      expect(snap.orgCommissionCents, 1600);
      expect(snap.value, 20);

      // Later the org RAISES commission to 30% (append a new dated rate).
      final ratesNow = [
        ...ratesAtBooking,
        CommissionRate(
            type: CommissionType.percent,
            value: 30,
            effectiveFrom: DateTime.utc(2026, 6, 1)),
      ];
      // The rate in effect NOW is 30% ...
      expect(commissionInEffect(ratesNow, DateTime.utc(2026, 7, 1))!.value, 30);
      // ... but the PAST booking's snapshot is untouched — still $16.00 @ 20%.
      expect(snap.orgCommissionCents, 1600);
      expect(snap.value, 20);

      // A NEW booking placed now captures the new 30% rate = $24.00.
      final future = CommissionSnapshot.capture(
        bookingId: 'future',
        grossCents: 8000,
        rates: ratesNow,
        at: DateTime.utc(2026, 7, 1),
        isFirst: false,
      );
      expect(future.orgCommissionCents, 2400);
      expect(future.value, 30);
    });
  });

  group('live-math reuses platform_fee.dart (identical both sides)', () {
    test('platform-fee slice equals FeeItemization for the same booking', () {
      const gross = 8000;
      final item = CommissionItemization.compute(
        grossCents: gross,
        commissionType: CommissionType.percent,
        commissionValue: 20,
        isFirst: false, // recurring — the P0 season unit
      );
      // The rake line is byte-identical to the money page's shared module.
      final rake = FeeItemization.marketplace(
          bookingId: '', grossCents: gross, isFirst: false);
      expect(item.platformFeeCents, rake.feeCents); // 4% of $80 = $3.20
      expect(item.platformFeeCents, 320);
      expect(item.platformFeeBps, kRecurringFeeBps);
    });

    test('the split always sums to gross (org + platform + trainer net)', () {
      final item = CommissionItemization.compute(
        grossCents: 8000,
        commissionType: CommissionType.percent,
        commissionValue: 20,
        isFirst: false,
      );
      expect(
        item.orgCommissionCents + item.platformFeeCents + item.trainerNetCents,
        item.grossCents,
      );
      // 20% org = $16.00, 4% platform = $3.20, trainer nets the rest.
      expect(item.orgCommissionCents, 1600);
      expect(item.trainerNetCents, 8000 - 1600 - 320);
    });

    test('the intro-rate line differs ONLY in the platform-fee slice', () {
      final intro = CommissionItemization.compute(
          grossCents: 8000,
          commissionType: CommissionType.percent,
          commissionValue: 20,
          isFirst: true);
      // 18% intro rake, same 20% org cut.
      expect(intro.platformFeeCents, 1440);
      expect(intro.orgCommissionCents, 1600);
      expect(intro.trainerNetCents, 8000 - 1440 - 1600);
    });

    test('flat commission is capped so trainer net never goes negative', () {
      // A $200 flat fee on an $80 session cannot exceed gross − platform fee.
      final item = CommissionItemization.compute(
        grossCents: 8000,
        commissionType: CommissionType.flat,
        commissionValue: 200,
        isFirst: false,
      );
      expect(item.trainerNetCents, greaterThanOrEqualTo(0));
      expect(item.orgCommissionCents, 8000 - item.platformFeeCents);
    });

    test('org view and trainer view read the SAME numbers', () {
      // The card is audience-tinted but the itemization object is identical —
      // there is exactly one source of the three figures.
      final item = CommissionItemization.compute(
        grossCents: 9000,
        commissionType: CommissionType.percent,
        commissionValue: 25,
        isFirst: false,
      );
      // Both sides render from `item`; assert the invariant that defines "same".
      expect(item.orgCommissionCents, 2250); // 25% of $90
      expect(item.platformFeeCents, 360); // 4% of $90
      expect(item.trainerNetCents, 9000 - 2250 - 360);
    });
  });
}
