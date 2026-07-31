/// Coach OS — ORG↔TRAINER commission itemization (Provider-Model-Rebuild #5).
///
/// PURE Dart, ZERO Flutter/Supabase imports so it is trivially unit-testable and
/// safe on every target. This is the SINGLE source of truth for the commission
/// split SHAPE that BOTH sides see — the org (setting the cut) and the trainer
/// (seeing their net). One module, one math, so the two sides can NEVER disagree
/// (spec #5: "identical itemization shown to both sides").
///
/// It LAYERS on top of [FeeItemization] from `platform_fee.dart`: the Sporve
/// rake (platform fee) is computed there and reused here VERBATIM, so a booking's
/// platform-fee line is identical whether you look at the money page (#3) or this
/// commission preview. We do not re-derive the platform fee — we consume it.
///
/// MONEY HONESTY (L-003): this file moves NO money and is READ-ONLY DISPLAY. It
/// computes the RATES + SNAPSHOT math the org and trainer see; the actual split
/// payout (a Stripe transfer to the trainer's connected account) is DESIGN-ONLY,
/// behind a flag, documented in docs/COMMISSION-SPLIT-DESIGN.md — never wired live
/// off a compile. The authoritative figures are each side's Stripe payout / 1099.
///
/// EFFECTIVE-DATING (spec #5: "changing commission never rewrites past bookings"):
/// a commission is captured as a [CommissionSnapshot] at BOOKING time from the
/// rate in effect then ([commissionInEffect]). A later rate change adds a NEW
/// [CommissionRate] row — it does NOT mutate any existing snapshot. History is
/// immutable by construction: the snapshot holds the numbers, the rate list only
/// ever grows.
library;

import 'platform_fee.dart';

/// How an org takes its cut of a trainer's booking.
enum CommissionType {
  /// A percent (0..100) of the gross booking amount.
  percent,

  /// A flat fee in DOLLARS per session (converted to cents in the math).
  flat,
}

CommissionType commissionTypeFromString(String? s) =>
    (s == 'flat') ? CommissionType.flat : CommissionType.percent;

String commissionTypeToString(CommissionType t) =>
    t == CommissionType.flat ? 'flat' : 'percent';

/// One effective-dated commission rate the org set for a trainer. Mirrors a
/// `public.commission_rates` row (20260729_000500_commission_rates.sql). The
/// table is APPEND-ONLY: editing a commission inserts a new row with a later
/// [effectiveFrom]; past rows (and any booking snapshot taken under them) never
/// change.
class CommissionRate {
  final CommissionType type;

  /// percent → 0..100 ; flat → DOLLARS (>= 0).
  final num value;
  final DateTime effectiveFrom;

  const CommissionRate({
    required this.type,
    required this.value,
    required this.effectiveFrom,
  });

  factory CommissionRate.fromRow(Map<String, dynamic> row) => CommissionRate(
        type: commissionTypeFromString(row['commission_type']?.toString()),
        value: (row['commission_value'] as num?) ?? 0,
        effectiveFrom: DateTime.tryParse(
                (row['effective_from'] ?? row['created_at'] ?? '').toString())
                ?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// The rate in effect at [at]: the LATEST rate whose [effectiveFrom] is `<= at`.
/// Mirrors `resolve_member_commission(member, at)` (SQL): order by effective_from
/// desc, take the first that has already begun. Returns null when no rate has
/// taken effect yet (caller falls back to the legacy default — 0%).
CommissionRate? commissionInEffect(List<CommissionRate> rates, DateTime at) {
  CommissionRate? best;
  for (final r in rates) {
    if (!r.effectiveFrom.isAfter(at)) {
      if (best == null || r.effectiveFrom.isAfter(best.effectiveFrom)) {
        best = r;
      }
    }
  }
  return best;
}

/// The org's cut in CENTS for a [grossCents] booking at a given rate. Percent
/// mirrors the SQL snapshot math `round(gross_cents * value / 100)`; flat is
/// `round(value * 100)` (dollars→cents). Clamped to [0, [maxCents]] so the
/// trainer's net can never go negative when a flat fee exceeds what's left after
/// the platform rake.
int computeOrgCommissionCents(
  int grossCents,
  CommissionType type,
  num value, {
  required int maxCents,
}) {
  final raw = type == CommissionType.percent
      ? (grossCents * value / 100).round()
      : (value * 100).round();
  if (raw < 0) return 0;
  if (raw > maxCents) return maxCents;
  return raw;
}

/// One booking's full three-way split — the IDENTICAL shape the org and the
/// trainer both read. All money in integer cents (no float drift). Invariant:
/// [grossCents] == [platformFeeCents] + [orgCommissionCents] + [trainerNetCents].
class CommissionItemization {
  final int grossCents;

  /// Sporve's rake (from [FeeItemization] — reused, not re-derived).
  final int platformFeeCents;
  final int platformFeeBps;

  /// The org's cut.
  final int orgCommissionCents;

  /// What the trainer nets: gross − platform fee − org commission.
  final int trainerNetCents;

  final CommissionType commissionType;
  final num commissionValue;

  /// True when the platform fee is the FIRST-booking introduction rate (the two
  /// sides both see whether this is an intro or a recurring line).
  final bool isFirst;
  final String currency;

  const CommissionItemization({
    required this.grossCents,
    required this.platformFeeCents,
    required this.platformFeeBps,
    required this.orgCommissionCents,
    required this.trainerNetCents,
    required this.commissionType,
    required this.commissionValue,
    required this.isFirst,
    required this.currency,
  });

  /// Compute the split for a booking. [isFirst] selects the intro vs recurring
  /// platform rate (via [FeeItemization.marketplace], the shared rake source).
  factory CommissionItemization.compute({
    required int grossCents,
    required CommissionType commissionType,
    required num commissionValue,
    required bool isFirst,
    String currency = 'USD',
  }) {
    // Reuse platform_fee.dart VERBATIM so the rake line is byte-identical to the
    // money page (#3). We take only the platform-fee slice here.
    final rake = FeeItemization.marketplace(
      bookingId: '',
      grossCents: grossCents,
      isFirst: isFirst,
      currency: currency,
    );
    final maxCommission = grossCents - rake.feeCents;
    final org = computeOrgCommissionCents(
      grossCents,
      commissionType,
      commissionValue,
      maxCents: maxCommission < 0 ? 0 : maxCommission,
    );
    return CommissionItemization(
      grossCents: grossCents,
      platformFeeCents: rake.feeCents,
      platformFeeBps: rake.feeBps,
      orgCommissionCents: org,
      trainerNetCents: grossCents - rake.feeCents - org,
      commissionType: commissionType,
      commissionValue: commissionValue,
      isFirst: isFirst,
      currency: currency,
    );
  }

  /// Rebuild the itemization exactly as it was captured on a booking row — from
  /// the immutable SNAPSHOT columns (`commission_amount_cents`, plus the stored
  /// platform-fee slice), NOT by recomputing against the current rate. This is
  /// what a HISTORICAL booking shows, guaranteeing a later rate change never
  /// alters it (spec #5). [platformFeeCents] is the fee the charge actually
  /// recorded when known; otherwise pass the schedule projection.
  factory CommissionItemization.fromSnapshot({
    required int grossCents,
    required int platformFeeCents,
    required int platformFeeBps,
    required int orgCommissionCents,
    required CommissionType commissionType,
    required num commissionValue,
    required bool isFirst,
    String currency = 'USD',
  }) =>
      CommissionItemization(
        grossCents: grossCents,
        platformFeeCents: platformFeeCents,
        platformFeeBps: platformFeeBps,
        orgCommissionCents: orgCommissionCents,
        trainerNetCents: grossCents - platformFeeCents - orgCommissionCents,
        commissionType: commissionType,
        commissionValue: commissionValue,
        isFirst: isFirst,
        currency: currency,
      );

  double get gross => grossCents / 100.0;
  double get platformFee => platformFeeCents / 100.0;
  double get orgCommission => orgCommissionCents / 100.0;
  double get trainerNet => trainerNetCents / 100.0;

  /// "20%" / "$25 / session" — the commission as a display string.
  String get commissionLabel => commissionType == CommissionType.percent
      ? '${commissionValue.round()}%'
      : '\$${commissionValue.round()} / session';

  /// "18%" / "4%" — the platform rake rate as a display string.
  String get platformRatePct {
    final pct = platformFeeBps / 100.0;
    return pct == pct.roundToDouble()
        ? '${pct.toStringAsFixed(0)}%'
        : '${pct.toStringAsFixed(1)}%';
  }
}

/// The frozen commission a booking captured at booking time — the SNAPSHOT that
/// makes history immutable. Built from [commissionInEffect] at the moment of
/// booking; thereafter it is a plain value object that no rate change touches.
class CommissionSnapshot {
  final String bookingId;
  final int grossCents;
  final CommissionType type;
  final num value;
  final int orgCommissionCents;
  final DateTime capturedAt;

  const CommissionSnapshot({
    required this.bookingId,
    required this.grossCents,
    required this.type,
    required this.value,
    required this.orgCommissionCents,
    required this.capturedAt,
  });

  /// Capture the snapshot for a booking placed at [at], using the org's rate
  /// history. Mirrors the SQL trigger that writes the `bookings.commission_*`
  /// columns on insert. When no rate is in effect, the cut is zero (the trainer
  /// keeps everything but the platform rake), matching the legacy default.
  factory CommissionSnapshot.capture({
    required String bookingId,
    required int grossCents,
    required List<CommissionRate> rates,
    required DateTime at,
    required bool isFirst,
  }) {
    final rate = commissionInEffect(rates, at);
    final type = rate?.type ?? CommissionType.percent;
    final value = rate?.value ?? 0;
    final item = CommissionItemization.compute(
      grossCents: grossCents,
      commissionType: type,
      commissionValue: value,
      isFirst: isFirst,
    );
    return CommissionSnapshot(
      bookingId: bookingId,
      grossCents: grossCents,
      type: type,
      value: value,
      orgCommissionCents: item.orgCommissionCents,
      capturedAt: at,
    );
  }
}
