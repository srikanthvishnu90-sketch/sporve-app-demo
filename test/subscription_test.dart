import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/models/subscription.dart';

void main() {
  group('SubscriptionPlan', () {
    test('parses the server entitlement shape', () {
      final plan = SubscriptionPlan.fromMap({
        'plan': 'pro',
        'ai_monthly_quota': null,
        'seat_limit': 3,
        'workspace_enabled': false,
        'purchasable': true,
        'price_usd_month': 34.99,
        'updated_at': '2026-08-17T00:00:00Z',
      });

      expect(plan.tier, SubscriptionTier.pro);
      expect(plan.aiMonthlyQuota, isNull);
      expect(plan.seatLimit, 3);
      expect(plan.priceLabel, r'$34.99');
      expect(plan.aiLabel, 'Unlimited AI actions');
      expect(plan.seatsLabel, '3 workspace seats');
    });

    test('unknown plan names fall back safely to Free', () {
      final plan = SubscriptionPlan.fromMap({
        'plan': 'future-plan',
        'price_usd_month': '0',
        'purchasable': true,
      });
      expect(plan.tier, SubscriptionTier.free);
      expect(plan.priceLabel, r'$0');
    });
  });

  group('ProviderSubscription', () {
    test('parses server-controlled provider billing state', () {
      final subscription = ProviderSubscription.fromMap({
        'id': 'provider-1',
        'plan': 'enterprise',
        'plan_status': 'active',
        'plan_period_end': '2026-09-01T00:00:00Z',
        'founding_coach': true,
        'stripe_customer_id': 'cus_test',
      });
      expect(subscription.tier, SubscriptionTier.enterprise);
      expect(subscription.status, SubscriptionStatus.active);
      expect(subscription.foundingCoach, true);
      expect(subscription.canManageBilling, true);
      expect(subscription.hasEntitlementAt(DateTime.utc(2027)), true);
    });

    test('past-due access expires at the server period end', () {
      final subscription = ProviderSubscription.fromMap({
        'plan': 'pro',
        'plan_status': 'past_due',
        'plan_period_end': '2026-09-01T00:00:00Z',
      });
      expect(subscription.hasEntitlementAt(DateTime.utc(2026, 8, 31)), true);
      expect(subscription.hasEntitlementAt(DateTime.utc(2026, 9, 2)), false);
      expect(
        subscription.effectiveTierAt(DateTime.utc(2026, 9, 2)),
        SubscriptionTier.free,
      );
    });

    test('redirect parameters cannot grant entitlement', () {
      const subscription = ProviderSubscription(
        providerId: 'provider-1',
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.incomplete,
        currentPeriodEnd: null,
        foundingCoach: false,
        hasStripeCustomer: true,
      );
      expect(subscription.hasEntitlementAt(DateTime.utc(2026)), false);
    });

    test('Free access is available without a Stripe customer', () {
      const subscription = ProviderSubscription.free();
      expect(subscription.hasEntitlementAt(DateTime.utc(2026)), true);
      expect(subscription.canManageBilling, false);
    });
  });
}
