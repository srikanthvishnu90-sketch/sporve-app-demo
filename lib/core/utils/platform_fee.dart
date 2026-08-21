/// Booking-money itemization for a subscription-funded Sporve workspace.
///
/// PURE Dart, ZERO Flutter/Supabase imports so it is trivially unit-testable and
/// safe on every target. This is the SINGLE source of truth for the itemization
/// SHAPE that the coach sees today and the org/trainer will see later — one
/// module, one math, so the two sides can never disagree (spec item #2:
/// "IDENTICAL itemization shape the coach and (later) the org/trainer both see").
///
/// MONEY HONESTY (L-003): this file moves NO money and is READ-ONLY DISPLAY. The
/// authoritative fee for a completed charge is the nullable amount recorded on
/// the booking by the Stripe webhook. Missing historical values stay unknown;
/// they are never rebuilt using today's policy. New bookings and invoices have
/// one policy: Sporve deducts nothing because revenue comes from subscriptions.
library;

import '../generated/contracts.dart';

/// The only current Sporve transaction-fee setting. Stripe processing is
/// separate and is intentionally not estimated by the client.
const int kSporveBookingFeeBps = kContractSporveBookingFeeBps;

/// Fee to charge on a gross amount (minor units / cents) at a bps rate. Mirrors
/// the server EXACTLY: `Math.round((amount * bps) / 10000)`
/// (stripe-create-checkout/index.ts) so the coach's preview equals the charge.
int feeCentsFor(int grossCents, int bps) => (grossCents * bps / 10000).round();

/// One booking's itemization: gross → Sporve fee → amount before processor fees.
/// All money uses integer minor units (cents) to avoid float drift.
class FeeItemization {
  final String bookingId;
  final int grossCents;
  final int feeBps;
  final int feeCents;
  final int netCents;

  /// False means an older paid row has no webhook-captured fee fact. In that
  /// case [feeCents] is zero only as a display placeholder and [netCents] is the
  /// pre-processing gross—not a claimed bank payout.
  final bool feeKnown;

  /// True when the amount came from a completed payment record, rather than a
  /// current-policy preview.
  final bool isRecorded;

  /// Legacy first-relationship metadata. It no longer changes Sporve's fee.
  final bool isFirst;

  /// True for an off-platform invoice line.
  final bool isOffPlatform;
  final String currency;

  const FeeItemization({
    required this.bookingId,
    required this.grossCents,
    required this.feeBps,
    required this.feeCents,
    required this.netCents,
    required this.feeKnown,
    required this.isRecorded,
    required this.isFirst,
    required this.currency,
    this.isOffPlatform = false,
  });

  /// Current booking preview. There is no first-booking, recurring-booking, or
  /// marketplace commission branch in the subscription model.
  factory FeeItemization.subscriptionFunded({
    required String bookingId,
    required int grossCents,
    String currency = 'USD',
    bool isOffPlatform = false,
  }) {
    final fee = feeCentsFor(grossCents, kSporveBookingFeeBps);
    return FeeItemization(
      bookingId: bookingId,
      grossCents: grossCents,
      feeBps: kSporveBookingFeeBps,
      feeCents: fee,
      netCents: grossCents - fee,
      feeKnown: true,
      isRecorded: false,
      isFirst: false,
      isOffPlatform: isOffPlatform,
      currency: currency,
    );
  }

  /// Current invoice preview. It shares the subscription-funded zero-fee path.
  factory FeeItemization.offPlatform({
    required String bookingId,
    required int grossCents,
    String currency = 'USD',
  }) => FeeItemization.subscriptionFunded(
    bookingId: bookingId,
    grossCents: grossCents,
    currency: currency,
    isOffPlatform: true,
  );

  /// A webhook-captured historical line. This is the only factory earnings
  /// history should use when it claims an exact Sporve fee or provider amount.
  factory FeeItemization.recorded({
    required String bookingId,
    required int grossCents,
    required int feeCents,
    int? feeBps,
    int? netCents,
    bool isFirst = false,
    bool isOffPlatform = false,
    String currency = 'USD',
  }) {
    final safeFee = feeCents.clamp(0, grossCents);
    final safeNet = (netCents ?? (grossCents - safeFee)).clamp(0, grossCents);
    final resolvedBps =
        feeBps ??
        (grossCents == 0 ? 0 : (safeFee * 10000 / grossCents).round());
    return FeeItemization(
      bookingId: bookingId,
      grossCents: grossCents,
      feeBps: resolvedBps,
      feeCents: safeFee,
      netCents: safeNet,
      feeKnown: true,
      isRecorded: true,
      isFirst: isFirst,
      isOffPlatform: isOffPlatform,
      currency: currency,
    );
  }

  /// A historical paid row without fee facts. Values remain usable for gross
  /// reporting while the UI/CSV explicitly leaves fee and net unknown.
  factory FeeItemization.unknown({
    required String bookingId,
    required int grossCents,
    bool isFirst = false,
    String currency = 'USD',
  }) => FeeItemization(
    bookingId: bookingId,
    grossCents: grossCents,
    feeBps: 0,
    feeCents: 0,
    netCents: grossCents,
    feeKnown: false,
    isRecorded: false,
    isFirst: isFirst,
    currency: currency,
  );

  double get gross => grossCents / 100.0;
  double get fee => feeCents / 100.0;
  double get net => netCents / 100.0;

  /// The rate as a display string. Callers must check [feeKnown] first.
  String get ratePct {
    final pct = feeBps / 100.0;
    return pct == pct.roundToDouble()
        ? '${pct.toStringAsFixed(0)}%'
        : '${pct.toStringAsFixed(1)}%';
  }
}

/// One coach earnings line to itemize. [familyKey] and [sortKey] remain only to
/// interpret historical relationship metadata; they do not select a fee rate.
class FeeInput {
  final String bookingId;
  final String familyKey;

  /// Sortable key for "which came first" — an ISO date/time string works; ties
  /// break on [bookingId] for determinism.
  final String sortKey;
  final int grossCents;
  final String currency;
  final int? recordedFeeCents;
  final int? recordedFeeBps;
  final int? recordedNetCents;

  const FeeInput({
    required this.bookingId,
    required this.familyKey,
    required this.sortKey,
    required this.grossCents,
    this.currency = 'USD',
    this.recordedFeeCents,
    this.recordedFeeBps,
    this.recordedNetCents,
  });
}

/// Itemize paid history. Recorded values win; missing values remain unknown.
/// First-family grouping is retained only as historical metadata.
List<FeeItemization> itemizeCoachEarnings(List<FeeInput> inputs) {
  // Determine, per family, which booking id is the earliest (the intro one).
  final byFamily = <String, List<FeeInput>>{};
  for (final i in inputs) {
    byFamily.putIfAbsent(i.familyKey, () => <FeeInput>[]).add(i);
  }
  final firstIds = <String>{};
  for (final group in byFamily.values) {
    final sorted = [...group]
      ..sort((a, b) {
        final c = a.sortKey.compareTo(b.sortKey);
        return c != 0 ? c : a.bookingId.compareTo(b.bookingId);
      });
    if (sorted.isNotEmpty) firstIds.add(sorted.first.bookingId);
  }
  return inputs.map((i) {
    final isFirst = firstIds.contains(i.bookingId);
    final derivedFee =
        i.recordedFeeCents ??
        (i.recordedNetCents == null
            ? null
            : i.grossCents - i.recordedNetCents!);
    if (derivedFee != null) {
      return FeeItemization.recorded(
        bookingId: i.bookingId,
        grossCents: i.grossCents,
        feeCents: derivedFee,
        feeBps: i.recordedFeeBps,
        netCents: i.recordedNetCents,
        isFirst: isFirst,
        currency: i.currency,
      );
    }
    return FeeItemization.unknown(
      bookingId: i.bookingId,
      grossCents: i.grossCents,
      isFirst: isFirst,
      currency: i.currency,
    );
  }).toList();
}

/// Aggregate of a list of itemizations — the coach's running totals for the
/// dashboard / pending-payout figure. All in cents.
class FeeTotals {
  final int count;
  final int grossCents;
  final int feeCents;
  final int netCents;
  final int unknownFeeCount;
  final String currency;
  const FeeTotals({
    required this.count,
    required this.grossCents,
    required this.feeCents,
    required this.netCents,
    required this.unknownFeeCount,
    required this.currency,
  });

  double get gross => grossCents / 100.0;
  double get fee => feeCents / 100.0;
  double get net => netCents / 100.0;
}

FeeTotals totalsOf(List<FeeItemization> items) {
  var gross = 0, fee = 0, net = 0;
  var unknown = 0;
  var currency = 'USD';
  for (final i in items) {
    gross += i.grossCents;
    fee += i.feeCents;
    net += i.netCents;
    if (!i.feeKnown) unknown++;
    if (i.currency.isNotEmpty) currency = i.currency;
  }
  return FeeTotals(
    count: items.length,
    grossCents: gross,
    feeCents: fee,
    netCents: net,
    unknownFeeCount: unknown,
    currency: currency,
  );
}
