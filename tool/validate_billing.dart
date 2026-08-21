import 'package:sporve_app/core/models/subscription.dart';
import 'package:sporve_app/core/utils/commission.dart';
import 'package:sporve_app/core/utils/earnings_csv.dart';
import 'package:sporve_app/core/utils/platform_fee.dart';
import 'package:sporve_app/core/utils/team_split.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final pro = SubscriptionPlan.fromMap({
    'plan': 'pro',
    'ai_monthly_quota': null,
    'seat_limit': 3,
    'workspace_enabled': false,
    'purchasable': true,
    'price_usd_month': 34.99,
  });
  check(pro.tier == SubscriptionTier.pro, 'Pro plan did not parse.');
  check(pro.priceLabel == r'$34.99', 'Pro price did not parse.');

  final expired = ProviderSubscription.fromMap({
    'plan': 'pro',
    'plan_status': 'past_due',
    'plan_period_end': '2026-09-01T00:00:00Z',
  });
  check(
    !expired.hasEntitlementAt(DateTime.utc(2026, 9, 2)),
    'Expired past-due access was granted.',
  );
  check(
    expired.effectiveTierAt(DateTime.utc(2026, 9, 2)) == SubscriptionTier.free,
    'Expired paid plan was presented as active.',
  );

  check(kSporveBookingFeeBps == 0, 'Sporve booking fee policy is not zero.');
  final current = FeeItemization.subscriptionFunded(
    bookingId: 'current',
    grossCents: 8000,
  );
  check(current.feeCents == 0, 'Current Sporve fee is not zero.');
  check(current.netCents == 8000, 'Zero-fee booking total changed.');

  final trainerSplit = CommissionItemization.compute(
    grossCents: 8000,
    commissionType: CommissionType.percent,
    commissionValue: 20,
    isFirst: true,
  );
  check(trainerSplit.platformFeeCents == 0, 'Trainer split charged Sporve.');
  check(trainerSplit.orgCommissionCents == 1600, 'Org share changed.');
  check(trainerSplit.trainerNetCents == 6400, 'Trainer share changed.');

  final teamBlock = TeamBlockPricing.compute(
    sessionCount: 3,
    unitPriceCents: 6751,
    paymentMode: 'split_pay',
    rosterSize: 4,
  );
  check(teamBlock.sharesSumCents == teamBlock.totalCents, 'Split lost money.');
  check(teamBlock.feeTotals.feeCents == 0, 'Team split charged Sporve.');

  final history = itemizeCoachEarnings(const [
    FeeInput(
      bookingId: 'recorded-zero',
      familyKey: 'family',
      sortKey: '2026-08-20',
      grossCents: 8000,
      recordedFeeCents: 0,
      recordedNetCents: 8000,
    ),
    FeeInput(
      bookingId: 'unknown',
      familyKey: 'family',
      sortKey: '2026-08-21',
      grossCents: 8000,
    ),
  ]);
  check(history.first.feeKnown, 'Recorded zero was treated as unknown.');
  check(!history.last.feeKnown, 'Missing historical fee was fabricated.');

  final csv = buildEarningsCsv(const [
    EarningsRow(
      date: '2026-08-20',
      athlete: 'Sam',
      program: 'Skills',
      sport: 'Soccer',
      status: 'completed',
      paymentStatus: 'paid',
      gross: 80,
      currency: 'USD',
    ),
  ], generatedAt: DateTime.utc(2026, 8, 20));
  check(csv.contains('80.00,,,USD'), 'Unknown CSV fees were not blank.');
  check(!csv.contains('estimated at'), 'Legacy fee estimate remains in CSV.');
}
