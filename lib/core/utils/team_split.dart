/// Team blocks (Provider Model Rebuild #9) — the split-pay SHARE MATH.
///
/// PURE Dart, zero Flutter/Supabase imports, so it is trivially unit-testable and
/// safe on every target. A `team_block` is a BUYER construct: N sessions bought for
/// a ROSTER of families. This module computes, for the two payment shapes, what each
/// party owes and the zero-deduction itemization — REUSING `platform_fee.dart` so
/// the team-block preview, the money page, and the server cannot disagree (L-021).
///
/// MONEY HONESTY (L-003): this file moves NO money and is READ-ONLY DISPLAY. The
/// authoritative charge and processing facts are set SERVER-SIDE at charge time;
/// generating a real payment link and capturing a share are DESIGN-ONLY behind a
/// flag (docs/TEAM-SPLIT-PAY-DESIGN.md). The cents math here MIRRORS the DB's
/// `team_block_even_shares` (penny-exact split).
library;

import 'platform_fee.dart';

/// Penny-exact even split of an integer cent [totalCents] across [n] families.
///
/// Returns a list of [n] shares that sum to EXACTLY [totalCents] — the remainder is
/// spread ONE cent each onto the FIRST `rem` shares, so no penny is lost or created.
/// This MIRRORS the DB function `team_block_even_shares(total, n)` (20260729_000900);
/// both must stay identical. Returns `[]` for `n <= 0`.
List<int> splitShares(int totalCents, int n) {
  if (n <= 0) return const [];
  final base = totalCents ~/ n; // integer floor division
  final rem = totalCents - base * n; // 0 <= rem < n
  return List<int>.generate(n, (i) => base + (i < rem ? 1 : 0));
}

/// One family's line in a split-pay team block: what they pay and the matching
/// subscription-funded booking itemization. Sporve does not take a share.
class TeamShare {
  final int shareCents;

  /// Current zero-fee Sporve itemization on this share.
  final FeeItemization item;
  final String currency;

  const TeamShare({
    required this.shareCents,
    required this.item,
    required this.currency,
  });

  double get share => shareCents / 100.0;
}

/// The full pricing of a team block for [rosterSize] families.
///
/// Block gross = [sessionCount] × [unitPriceCents]. Depending on [paymentMode]:
///   • `one_payer` — [shares] is a single line for the whole block gross.
///   • `split_pay` — [shares] is one penny-exact line per family.
/// [feeTotals] aggregates the Sporve fee / pre-processing coach amount.
class TeamBlockPricing {
  final int sessionCount;
  final int unitPriceCents;
  final String paymentMode; // 'one_payer' | 'split_pay'
  final int rosterSize;
  final List<TeamShare> shares;
  final String currency;

  const TeamBlockPricing({
    required this.sessionCount,
    required this.unitPriceCents,
    required this.paymentMode,
    required this.rosterSize,
    required this.shares,
    required this.currency,
  });

  /// Block gross in cents = sessions × per-session price.
  int get totalCents => sessionCount * unitPriceCents;
  double get total => totalCents / 100.0;

  /// The shares always sum to [totalCents] (invariant the tests pin).
  int get sharesSumCents => shares.fold(0, (a, s) => a + s.shareCents);

  /// Aggregate Sporve fee / pre-processing amount across every share.
  FeeTotals get feeTotals => totalsOf(shares.map((s) => s.item).toList());

  static TeamBlockPricing compute({
    required int sessionCount,
    required int unitPriceCents,
    required String paymentMode,
    required int rosterSize,
    String currency = 'USD',
  }) {
    final total = sessionCount * unitPriceCents;
    final List<TeamShare> lines;

    if (paymentMode == 'one_payer') {
      // One family/org pays the whole block gross.
      final item = FeeItemization.subscriptionFunded(
        bookingId: 'team_block',
        grossCents: total,
        currency: currency,
      );
      lines = [TeamShare(shareCents: total, item: item, currency: currency)];
    } else {
      // split_pay: one penny-exact share per family.
      final cents = splitShares(total, rosterSize);
      lines = [
        for (var i = 0; i < cents.length; i++)
          TeamShare(
            shareCents: cents[i],
            item: FeeItemization.subscriptionFunded(
              bookingId: 'team_share_$i',
              grossCents: cents[i],
              currency: currency,
            ),
            currency: currency,
          ),
      ];
    }

    return TeamBlockPricing(
      sessionCount: sessionCount,
      unitPriceCents: unitPriceCents,
      paymentMode: paymentMode,
      rosterSize: rosterSize,
      shares: lines,
      currency: currency,
    );
  }
}
