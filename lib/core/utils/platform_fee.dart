/// Coach OS — per-transaction PLATFORM FEE itemization (P0 #2 / #3, money page).
///
/// PURE Dart, ZERO Flutter/Supabase imports so it is trivially unit-testable and
/// safe on every target. This is the SINGLE source of truth for the itemization
/// SHAPE that the coach sees today and the org/trainer will see later — one
/// module, one math, so the two sides can never disagree (spec item #2:
/// "IDENTICAL itemization shape the coach and (later) the org/trainer both see").
///
/// MONEY HONESTY (L-003): this file moves NO money and is READ-ONLY DISPLAY. The
/// authoritative platform fee for each charge is set SERVER-SIDE by Stripe at
/// charge time (`stripe-create-checkout` → `application_fee_amount`), derived
/// there from `resolve_platform_fee_bps` / `platform_fees`. The rates below
/// MIRROR that DB config so the coach sees a faithful preview, but the coach's
/// Stripe payout / 1099-K is the authoritative fee record. A row whose real
/// charged fee is later mirrored onto the booking should override the computed
/// fee — until then this is the current fee-schedule projection, labeled as such
/// in the UI + CSV.
///
/// Fee schedule (basis points) mirrors `platform_fees` defaults
/// (supabase/migrations/20260728_000101_platform_fees.sql): the FULL introduction
/// rate on a family's FIRST paid booking with a coach, a THIN relationship rate
/// on every booking thereafter — "we charge for introductions, not
/// relationships." Off-platform invoices (families Sporve did not source) carry a
/// near-zero SaaS rate (docs/COACH-OS-INVOICING-DESIGN.md §2).
library;

/// 18% — full introduction rate on a family's FIRST paid booking with a coach.
const int kFirstBookingFeeBps = 1800;

/// 4% — thin relationship rate on every subsequent booking with the same coach.
const int kRecurringFeeBps = 400;

/// ~2.5% — near-zero SaaS rate on an OFF-PLATFORM invoice (a family the coach
/// brought, not an introduction Sporve earned). Mirrors the NEW
/// `platform_fees.offplatform_rate_bps`; tunable server-side, never client-set.
const int kOffPlatformFeeBps = 250;

/// Fee to charge on a gross amount (minor units / cents) at a bps rate. Mirrors
/// the server EXACTLY: `Math.round((amount * bps) / 10000)`
/// (stripe-create-checkout/index.ts) so the coach's preview equals the charge.
int feeCentsFor(int grossCents, int bps) => (grossCents * bps / 10000).round();

/// One booking's fee itemization: gross → platform fee → coach net. All money in
/// integer minor units (cents) to match the server's cents math with no float
/// drift. Dollar getters are conveniences for display only.
class FeeItemization {
  final String bookingId;
  final int grossCents;
  final int feeBps;
  final int feeCents;
  final int netCents;

  /// True when this is the family's FIRST paid booking with the coach (the intro
  /// rate applied). Off-platform invoices set this false and use the SaaS bps.
  final bool isFirst;

  /// True for an off-platform invoice line (near-zero SaaS rate), so the UI can
  /// label the fee "SaaS fee" instead of "platform fee".
  final bool isOffPlatform;
  final String currency;

  const FeeItemization({
    required this.bookingId,
    required this.grossCents,
    required this.feeBps,
    required this.feeCents,
    required this.netCents,
    required this.isFirst,
    required this.currency,
    this.isOffPlatform = false,
  });

  /// Marketplace booking itemization. [isFirst] selects the intro vs recurring
  /// rate (resolve_platform_fee_bps semantics).
  factory FeeItemization.marketplace({
    required String bookingId,
    required int grossCents,
    required bool isFirst,
    String currency = 'USD',
  }) {
    final bps = isFirst ? kFirstBookingFeeBps : kRecurringFeeBps;
    final fee = feeCentsFor(grossCents, bps);
    return FeeItemization(
      bookingId: bookingId,
      grossCents: grossCents,
      feeBps: bps,
      feeCents: fee,
      netCents: grossCents - fee,
      isFirst: isFirst,
      currency: currency,
    );
  }

  /// Off-platform invoice itemization — near-zero SaaS rate, never the intro rake.
  factory FeeItemization.offPlatform({
    required String bookingId,
    required int grossCents,
    int bps = kOffPlatformFeeBps,
    String currency = 'USD',
  }) {
    final fee = feeCentsFor(grossCents, bps);
    return FeeItemization(
      bookingId: bookingId,
      grossCents: grossCents,
      feeBps: bps,
      feeCents: fee,
      netCents: grossCents - fee,
      isFirst: false,
      isOffPlatform: true,
      currency: currency,
    );
  }

  double get gross => grossCents / 100.0;
  double get fee => feeCents / 100.0;
  double get net => netCents / 100.0;

  /// "18%" / "4%" / "2.5%" — the rate as a display string.
  String get ratePct {
    final pct = feeBps / 100.0;
    return pct == pct.roundToDouble()
        ? '${pct.toStringAsFixed(0)}%'
        : '${pct.toStringAsFixed(1)}%';
  }
}

/// One coach earnings line to itemize. The [familyKey] groups a coach's bookings
/// by the paying family (searcher/athlete) so first-vs-recurring can be resolved
/// exactly the way `resolve_platform_fee_bps(searcher, provider)` does — the
/// EARLIEST paid booking with a family pays the intro rate, the rest are thin.
class FeeInput {
  final String bookingId;
  final String familyKey;

  /// Sortable key for "which came first" — an ISO date/time string works; ties
  /// break on [bookingId] for determinism.
  final String sortKey;
  final int grossCents;
  final String currency;

  const FeeInput({
    required this.bookingId,
    required this.familyKey,
    required this.sortKey,
    required this.grossCents,
    this.currency = 'USD',
  });
}

/// Itemize a coach's paid bookings into gross → fee → net lines, marking the
/// FIRST paid booking with each family as the intro-rate line and the rest as
/// recurring. Returns one [FeeItemization] per input, in the SAME order as
/// [inputs] (so a caller can zip it back onto its own rows).
///
/// This mirrors `resolve_platform_fee_bps`: the rate is per (family, coach), not
/// per family globally and not per booking in isolation. Deterministic:
/// grouped by [FeeInput.familyKey], ordered by (sortKey, bookingId).
List<FeeItemization> itemizeCoachEarnings(List<FeeInput> inputs) {
  // Determine, per family, which booking id is the earliest (the intro one).
  final byFamily = <String, List<FeeInput>>{};
  for (final i in inputs) {
    byFamily.putIfAbsent(i.familyKey, () => <FeeInput>[]).add(i);
  }
  final firstIds = <String>{};
  for (final group in byFamily.values) {
    final sorted = [...group]..sort((a, b) {
      final c = a.sortKey.compareTo(b.sortKey);
      return c != 0 ? c : a.bookingId.compareTo(b.bookingId);
    });
    if (sorted.isNotEmpty) firstIds.add(sorted.first.bookingId);
  }
  return inputs
      .map((i) => FeeItemization.marketplace(
            bookingId: i.bookingId,
            grossCents: i.grossCents,
            isFirst: firstIds.contains(i.bookingId),
            currency: i.currency,
          ))
      .toList();
}

/// Aggregate of a list of itemizations — the coach's running totals for the
/// dashboard / pending-payout figure. All in cents.
class FeeTotals {
  final int count;
  final int grossCents;
  final int feeCents;
  final int netCents;
  final String currency;
  const FeeTotals({
    required this.count,
    required this.grossCents,
    required this.feeCents,
    required this.netCents,
    required this.currency,
  });

  double get gross => grossCents / 100.0;
  double get fee => feeCents / 100.0;
  double get net => netCents / 100.0;
}

FeeTotals totalsOf(List<FeeItemization> items) {
  var gross = 0, fee = 0, net = 0;
  var currency = 'USD';
  for (final i in items) {
    gross += i.grossCents;
    fee += i.feeCents;
    net += i.netCents;
    if (i.currency.isNotEmpty) currency = i.currency;
  }
  return FeeTotals(
    count: items.length,
    grossCents: gross,
    feeCents: fee,
    netCents: net,
    currency: currency,
  );
}
