/// Coach OS — tax-season earnings export (P0 #3, docs/ITERATION-ROADMAP.md).
///
/// PURE Dart, ZERO Flutter/Supabase imports so it is trivially unit-testable and
/// safe on every target. Given the provider's OWN paid bookings (already readable
/// via RLS — the finances screen derives revenue from the same rows), this builds
/// a spreadsheet-ready CSV: one line per paid session + a totals block.
///
/// MONEY HONESTY (L-003): this file moves NO money and is READ-ONLY. The exact
/// platform fee for each charge is set server-side by Stripe at charge time and
/// is not mirrored per-booking on the client. Where a real per-booking fee is not
/// present in the row, the net column is computed from a DISPLAYED [feeRate] and
/// the CSV header labels it an ESTIMATE — the coach's authoritative fee record is
/// their Stripe/1099-K. This export is a convenience worksheet, not a tax filing.
library;

/// The fraction of gross the platform takes, used only to ESTIMATE net when a
/// row carries no real fee amount. Mirrors the finances screen's display rate
/// (kPlatformFeeRate = 0.10). Kept here so the pure builder has no UI dependency.
const double kEarningsEstimatedFeeRate = 0.10;

/// One normalized earnings line. Keys are read defensively so both data shapes
/// (Flutter mock camelCase, Supabase-mapped) flow through unchanged (L-010).
class EarningsRow {
  final String date; // ISO 'YYYY-MM-DD' (session/booking calendar day)
  final String athlete; // denormalized first name only (never PII)
  final String program;
  final String sport;
  final String status;
  final String paymentStatus;
  final double gross; // what the family paid (final_price)
  final double? fee; // real fee if known; null => estimate from feeRate
  final String currency;

  const EarningsRow({
    required this.date,
    required this.athlete,
    required this.program,
    required this.sport,
    required this.status,
    required this.paymentStatus,
    required this.gross,
    required this.currency,
    this.fee,
  });

  double feeAt(double rate) => fee ?? (gross * rate);
  double netAt(double rate) => gross - feeAt(rate);
}

/// Aggregate totals across the rows, for the summary block + the UI confirmation.
class EarningsSummary {
  final int count;
  final double gross;
  final double fee;
  final double net;
  final String currency;
  const EarningsSummary({
    required this.count,
    required this.gross,
    required this.fee,
    required this.net,
    required this.currency,
  });
}

EarningsSummary summarizeEarnings(
  List<EarningsRow> rows, {
  double feeRate = kEarningsEstimatedFeeRate,
}) {
  double gross = 0, fee = 0, net = 0;
  String currency = 'USD';
  for (final r in rows) {
    gross += r.gross;
    fee += r.feeAt(feeRate);
    net += r.netAt(feeRate);
    if (r.currency.isNotEmpty) currency = r.currency;
  }
  return EarningsSummary(
    count: rows.length,
    gross: gross,
    fee: fee,
    net: net,
    currency: currency,
  );
}

/// RFC-4180 field escaping: wrap in quotes when the value contains a comma,
/// quote, or newline; double any embedded quotes.
String _csvField(Object? value) {
  final s = (value ?? '').toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _csvLine(List<Object?> cells) => cells.map(_csvField).join(',');

String _money(double v) => v.toStringAsFixed(2);

/// Build the full CSV document. Deterministic column order; a leading provenance
/// comment (as ordinary quoted first-column cells) documents the estimate caveat
/// without breaking the header row for spreadsheet importers.
String buildEarningsCsv(
  List<EarningsRow> rows, {
  double feeRate = kEarningsEstimatedFeeRate,
  String? providerName,
  DateTime? generatedAt,
}) {
  final when = (generatedAt ?? DateTime.now()).toUtc().toIso8601String();
  final summary = summarizeEarnings(rows, feeRate: feeRate);
  final pct = (feeRate * 100).toStringAsFixed(1);

  final buf = StringBuffer();
  // Provenance / caveat rows (single-column, quoted so importers ignore extras).
  buf.writeln(
    _csvLine(['Sporve earnings export${providerName != null ? ' — $providerName' : ''}']),
  );
  buf.writeln(_csvLine(['Generated (UTC)', when]));
  buf.writeln(_csvLine([
    'NOTE',
    'Net is estimated at $pct% platform fee where a real fee is unavailable. '
        'Your Stripe/1099-K is the authoritative fee record.',
  ]));
  buf.writeln(''); // blank separator line

  // Header + rows.
  buf.writeln(_csvLine([
    'Date',
    'Athlete',
    'Program',
    'Sport',
    'Status',
    'Payment',
    'Gross',
    'Fee (est.)',
    'Net (est.)',
    'Currency',
  ]));
  for (final r in rows) {
    buf.writeln(_csvLine([
      r.date,
      r.athlete,
      r.program,
      r.sport,
      r.status,
      r.paymentStatus,
      _money(r.gross),
      _money(r.feeAt(feeRate)),
      _money(r.netAt(feeRate)),
      r.currency,
    ]));
  }

  // Totals block.
  buf.writeln('');
  buf.writeln(_csvLine([
    'TOTALS',
    '${summary.count} sessions',
    '',
    '',
    '',
    '',
    _money(summary.gross),
    _money(summary.fee),
    _money(summary.net),
    summary.currency,
  ]));
  return buf.toString();
}
