// Provider Model Rebuild #9 — TEAM BLOCKS (a team is a BUYER, not an account).
// Two things are pinned here:
//   1. The SHARE MATH (team_split.dart) is penny-exact and reuses platform_fee.dart
//      (no second fee constant) — the same math the DB's team_block_even_shares uses.
//   2. The GROWTH MECHANIC on the mock: a redeemed split share provisions a
//      COPPA-consented parent/athlete AND generates the block's N session bookings,
//      while the money movement stays design-only (bookings land UNPAID — L-003).
//   flutter test test/team_split_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/mock_repository.dart';
import 'package:flutter_structure/core/utils/platform_fee.dart';
import 'package:flutter_structure/core/utils/team_split.dart';

void main() {
  const repo = MockRepository();

  group('splitShares — penny-exact, sums to total', () {
    test('even division', () {
      expect(splitShares(9000, 3), [3000, 3000, 3000]);
    });
    test('remainder spread onto the first shares, sums exactly', () {
      final s = splitShares(10001, 3);
      expect(s, [3334, 3334, 3333]);
      expect(s.reduce((a, b) => a + b), 10001); // no lost/created penny
    });
    test('n<=0 is empty (honest, not a divide-by-zero)', () {
      expect(splitShares(1000, 0), isEmpty);
    });
  });

  group('TeamBlockPricing reuses the zero-fee policy', () {
    test('split_pay shares sum to the block total with no Sporve fee', () {
      // 8 sessions x $75 = $600 block, split across 4 families.
      final p = TeamBlockPricing.compute(
        sessionCount: 8,
        unitPriceCents: 7500,
        paymentMode: 'split_pay',
        rosterSize: 4,
      );
      expect(p.totalCents, 60000);
      expect(p.shares.length, 4);
      expect(p.sharesSumCents, 60000); // invariant
      expect(p.shares.first.shareCents, 15000);
      expect(p.shares.first.item.feeBps, kSporveBookingFeeBps);
      expect(p.shares.first.item.feeCents, 0);
      expect(p.feeTotals.feeCents, 0);
    });

    test('one_payer: a single whole-block line', () {
      final p = TeamBlockPricing.compute(
        sessionCount: 10,
        unitPriceCents: 5000,
        paymentMode: 'one_payer',
        rosterSize: 6,
      );
      expect(p.shares.length, 1);
      expect(p.shares.single.shareCents, 50000);
      expect(p.shares.single.item.feeBps, kSporveBookingFeeBps);
      // Fee mirrors feeCentsFor exactly (no separate constant).
      expect(
        p.shares.single.item.feeCents,
        feeCentsFor(50000, kSporveBookingFeeBps),
      );
    });
  });

  group('redeemSplitShare — the dozen-parents growth mechanic (mock)', () {
    Future<String> setupSplitBlock({int sessions = 8, int members = 3}) async {
      final block = await repo.createTeamBlock(
        serviceId: 'svc-teamblock-${DateTime.now().microsecondsSinceEpoch}',
        teamName: 'U12 Travel',
        sessionCount: sessions,
        unitPriceCents: 7500,
        paymentMode: 'split_pay',
      );
      expect(block, isNotNull);
      for (var i = 0; i < members; i++) {
        final m = await repo.addTeamBlockMember(
          teamBlockId: block!,
          invitedEmail: 'family$i@example.com',
          memberLabel: 'Family $i',
        );
        expect(m, isNotNull);
      }
      final n = await repo.createSplitPayLinks(teamBlockId: block!);
      expect(n, members);
      return block;
    }

    test(
      'a paid share provisions a consent-gated parent/athlete + N bookings',
      () async {
        final block = await setupSplitBlock(sessions: 8, members: 3);
        final status = await repo.teamBlockSplitStatus(teamBlockId: block);
        expect(status.length, 3);
        // Shares came from the SAME split math (block total 60000 / 3).
        final shareSum = status.fold<int>(
          0,
          (a, m) => a + (m['shareAmountCents'] as int),
        );
        expect(shareSum, 60000);
        expect(status.every((m) => m['linkStatus'] == 'pending'), isTrue);

        // Redeem the first family's link. In the mock the token is on the status via
        // the split link; fetch it through the internal store is not exposed, so we
        // redeem by looking the token up the same way a family would (from the link).
        final token = _tokenForFirstMember(block);
        final generated = await repo.redeemSplitShare(
          token: token,
          athleteFirstName: 'Mia',
          athleteDob: '2016-05-01',
          consentVersion: 'v1-2026',
        );
        expect(generated, 8); // the block's N sessions became bookings

        // A COPPA-consented athlete was provisioned.
        final kids = MockRepository.teamBlockAthletesForTest.where(
          (a) => a['firstName'] == 'Mia',
        );
        expect(kids.length, 1);
        expect(kids.first['parentConsent'], isTrue);
        expect(kids.first['consentVersion'], 'v1-2026');
        expect(kids.first['consentAt'], isNotNull);

        // 8 bookings were generated against the block — and they are UNPAID (no real
        // charge; the link 'paid' is structure only, L-003).
        final bookings = MockRepository.teamBlockBookingsForTest
            .where((b) => b['athleteFirstName'] == 'Mia')
            .toList();
        expect(bookings.length, 8);
        expect(bookings.every((b) => b['paymentStatus'] == 'unpaid'), isTrue);
        expect(bookings.every((b) => b['status'] == 'confirmed'), isTrue);

        // The roster member is now onboarded + the link is paid.
        final after = await repo.teamBlockSplitStatus(teamBlockId: block);
        final paid = after.where((m) => m['linkStatus'] == 'paid').toList();
        expect(paid.length, 1);
        expect(paid.first['memberStatus'], 'onboarded');
        expect(paid.first['athleteFirstName'], 'Mia');
      },
    );

    test(
      'COPPA: an empty consent_version redeems NOTHING (gate, not bypass)',
      () async {
        final block = await setupSplitBlock(sessions: 5, members: 2);
        final token = _tokenForFirstMember(block);
        final before = MockRepository.teamBlockAthletesForTest.length;
        final generated = await repo.redeemSplitShare(
          token: token,
          athleteFirstName: 'Leo',
          athleteDob: '2017-01-01',
          consentVersion: '   ', // no consent captured
        );
        expect(generated, isNull); // honest failure (L-015)
        // No athlete provisioned, link still pending.
        expect(MockRepository.teamBlockAthletesForTest.length, before);
        final status = await repo.teamBlockSplitStatus(teamBlockId: block);
        expect(status.every((m) => m['linkStatus'] == 'pending'), isTrue);
      },
    );

    test(
      'a used link cannot be redeemed twice (idempotent no double-book)',
      () async {
        final block = await setupSplitBlock(sessions: 4, members: 1);
        final token = _tokenForFirstMember(block);
        final first = await repo.redeemSplitShare(
          token: token,
          athleteFirstName: 'Ada',
          athleteDob: '2015-09-09',
          consentVersion: 'v1-2026',
        );
        expect(first, 4);
        final second = await repo.redeemSplitShare(
          token: token,
          athleteFirstName: 'Ada',
          athleteDob: '2015-09-09',
          consentVersion: 'v1-2026',
        );
        expect(second, isNull); // link no longer pending
      },
    );
  });
}

// The mock stores the token on the split link; a family reads it from their link.
// The test reaches it through the status + the internal link store mirror exposed
// for tests. Since the token isn't surfaced on the status view (it's the secret),
// we recover it from the split-link store via the public test hook.
String _tokenForFirstMember(String block) {
  final link = MockRepository.splitPayLinksForTest.firstWhere(
    (l) => l['teamBlockId'] == block && l['status'] == 'pending',
  );
  return link['token'] as String;
}
