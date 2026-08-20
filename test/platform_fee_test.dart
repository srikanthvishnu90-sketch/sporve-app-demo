import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/utils/platform_fee.dart';

void main() {
  group('subscription-funded current policy', () {
    test('Sporve has one zero booking-fee policy', () {
      expect(kSporveBookingFeeBps, 0);
      expect(feeCentsFor(8000, kSporveBookingFeeBps), 0);
    });

    test('marketplace preview keeps the full booking amount', () {
      final item = FeeItemization.subscriptionFunded(
        bookingId: 'future',
        grossCents: 8000,
      );
      expect(item.feeCents, 0);
      expect(item.netCents, 8000);
      expect(item.ratePct, '0%');
      expect(item.feeKnown, true);
      expect(item.isRecorded, false);
    });

    test('off-platform preview also has no Sporve fee', () {
      final item = FeeItemization.offPlatform(
        bookingId: 'invoice',
        grossCents: 16000,
      );
      expect(item.isOffPlatform, true);
      expect(item.feeCents, 0);
      expect(item.netCents, 16000);
    });
  });

  group('historical money facts', () {
    test('recorded legacy fee is preserved exactly', () {
      final item = FeeItemization.recorded(
        bookingId: 'legacy',
        grossCents: 8000,
        feeCents: 1440,
        feeBps: 1800,
        netCents: 6560,
        isFirst: true,
      );
      expect(item.feeCents, 1440);
      expect(item.netCents, 6560);
      expect(item.ratePct, '18%');
      expect(item.feeKnown, true);
      expect(item.isRecorded, true);
    });

    test('missing fee remains unknown instead of being recomputed at zero', () {
      final out = itemizeCoachEarnings(const [
        FeeInput(
          bookingId: 'unknown',
          familyKey: 'family',
          sortKey: '2026-01-01',
          grossCents: 8000,
        ),
      ]);
      expect(out.single.feeKnown, false);
      expect(out.single.feeCents, 0);
      expect(out.single.netCents, 8000);
    });

    test('recorded zero fee is distinct from an unknown fee', () {
      final out = itemizeCoachEarnings(const [
        FeeInput(
          bookingId: 'zero',
          familyKey: 'family',
          sortKey: '2026-01-01',
          grossCents: 8000,
          recordedFeeCents: 0,
          recordedFeeBps: 0,
          recordedNetCents: 8000,
        ),
      ]);
      expect(out.single.feeKnown, true);
      expect(out.single.isRecorded, true);
      expect(out.single.ratePct, '0%');
    });

    test('provider amount can derive a missing recorded fee', () {
      final out = itemizeCoachEarnings(const [
        FeeInput(
          bookingId: 'derived',
          familyKey: 'family',
          sortKey: '2026-01-01',
          grossCents: 10000,
          recordedNetCents: 9600,
        ),
      ]);
      expect(out.single.feeCents, 400);
      expect(out.single.feeBps, 400);
      expect(out.single.isRecorded, true);
    });
  });

  test('totals disclose unknown fee rows', () {
    final totals = totalsOf([
      FeeItemization.subscriptionFunded(bookingId: 'current', grossCents: 8000),
      FeeItemization.unknown(bookingId: 'historical', grossCents: 5000),
    ]);
    expect(totals.grossCents, 13000);
    expect(totals.feeCents, 0);
    expect(totals.netCents, 13000);
    expect(totals.unknownFeeCount, 1);
  });
}
