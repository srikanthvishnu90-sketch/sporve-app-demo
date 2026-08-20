import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/utils/earnings_csv.dart';

void main() {
  test('unknown historical fees stay blank', () {
    final rows = [
      const EarningsRow(
        date: '2026-08-20',
        athlete: 'Sam',
        program: 'Skills',
        sport: 'Soccer',
        status: 'completed',
        paymentStatus: 'paid',
        gross: 80,
        currency: 'USD',
      ),
    ];

    final summary = summarizeEarnings(rows);
    final csv = buildEarningsCsv(rows, generatedAt: DateTime.utc(2026, 8, 20));

    expect(summary.gross, 80);
    expect(summary.fee, isNull);
    expect(summary.net, isNull);
    expect(summary.unknownFeeCount, 1);
    expect(csv, contains('80.00,,,USD'));
    expect(csv, isNot(contains('estimated at')));
  });

  test('recorded zero fee exports as an exact zero', () {
    final rows = [
      const EarningsRow(
        date: '2026-08-20',
        athlete: 'Sam',
        program: 'Skills',
        sport: 'Soccer',
        status: 'completed',
        paymentStatus: 'paid',
        gross: 80,
        fee: 0,
        currency: 'USD',
      ),
    ];

    final summary = summarizeEarnings(rows);
    final csv = buildEarningsCsv(rows, generatedAt: DateTime.utc(2026, 8, 20));

    expect(summary.fee, 0);
    expect(summary.net, 80);
    expect(summary.unknownFeeCount, 0);
    expect(csv, contains('80.00,0.00,80.00,USD'));
  });
}
