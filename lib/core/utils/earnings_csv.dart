/// Coach OS — tax-season earnings export (P0 #3, docs/ITERATION-ROADMAP.md).
///
/// PURE Dart, ZERO Flutter/Supabase imports so it is trivially unit-testable and
/// safe on every target. Given the provider's OWN paid bookings (already readable
/// via RLS — the finances screen derives revenue from the same rows), this builds
/// a spreadsheet-ready CSV: one line per paid session + a totals block.
///
/// MONEY HONESTY (L-003): this file moves NO money and is READ-ONLY. The exact
/// Sporve fee for each charge is set server-side and captured by the webhook.
/// Missing historical fee values remain blank—today's 0% subscription-funded
/// policy is never applied retroactively. Stripe reports remain authoritative.
library;

/// Retained for source compatibility. Earnings exports no longer estimate fees.
const double kEarningsEstimatedFeeRate = 0;

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
  final double? fee; // webhook-recorded Sporve fee; null means unknown
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

  double? get amountAfterSporveFee => fee == null ? null : gross - fee!;
}

/// Aggregate totals across the rows, for the summary block + the UI confirmation.
class EarningsSummary {
  final int count;
  final double gross;
  final double? fee;
  final double? net;
  final int unknownFeeCount;
  final String currency;
  const EarningsSummary({
    required this.count,
    required this.gross,
    required this.fee,
    required this.net,
    required this.unknownFeeCount,
    required this.currency,
  });
}

EarningsSummary summarizeEarnings(
  List<EarningsRow> rows, {
  // Deprecated and intentionally ignored: missing fees are unknown.
  double feeRate = kEarningsEstimatedFeeRate,
}) {
  double gross = 0, knownFee = 0, knownNet = 0;
  var unknown = 0;
  String currency = 'USD';
  for (final r in rows) {
    gross += r.gross;
    if (r.fee == null) {
      unknown++;
    } else {
      knownFee += r.fee!;
      knownNet += r.amountAfterSporveFee!;
    }
    if (r.currency.isNotEmpty) currency = r.currency;
  }
  return EarningsSummary(
    count: rows.length,
    gross: gross,
    fee: unknown == 0 ? knownFee : null,
    net: unknown == 0 ? knownNet : null,
    unknownFeeCount: unknown,
    currency: currency,
  );
}

/// RFC-4180 field escaping: wrap in quotes when the value contains a comma,
/// quote, or newline; double any embedded quotes.
String _csvField(Object? value) {
  final s = (value ?? '').toString();
  if (s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
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

  final buf = StringBuffer();
  // Provenance / caveat rows (single-column, quoted so importers ignore extras).
  buf.writeln(
    _csvLine([
      'Sporve earnings export${providerName != null ? ' — $providerName' : ''}',
    ]),
  );
  buf.writeln(_csvLine(['Generated (UTC)', when]));
  buf.writeln(
    _csvLine([
      'NOTE',
      'Sporve is subscription-funded and currently charges a 0% booking fee. '
          'Historical fee and after-fee cells are blank when no webhook record '
          'exists. Stripe reports are authoritative and processing fees are not '
          'estimated here.',
    ]),
  );
  buf.writeln(''); // blank separator line

  // Header + rows.
  buf.writeln(
    _csvLine([
      'Date',
      'Athlete',
      'Program',
      'Sport',
      'Status',
      'Payment',
      'Gross',
      'Recorded Sporve fee',
      'After Sporve fee (before Stripe processing)',
      'Currency',
    ]),
  );
  for (final r in rows) {
    buf.writeln(
      _csvLine([
        r.date,
        r.athlete,
        r.program,
        r.sport,
        r.status,
        r.paymentStatus,
        _money(r.gross),
        r.fee == null ? '' : _money(r.fee!),
        r.amountAfterSporveFee == null ? '' : _money(r.amountAfterSporveFee!),
        r.currency,
      ]),
    );
  }

  // Totals block.
  buf.writeln('');
  buf.writeln(
    _csvLine([
      'TOTALS',
      '${summary.count} sessions',
      '',
      '',
      '',
      '',
      _money(summary.gross),
      summary.fee == null ? '' : _money(summary.fee!),
      summary.net == null ? '' : _money(summary.net!),
      summary.currency,
    ]),
  );
  return buf.toString();
}
