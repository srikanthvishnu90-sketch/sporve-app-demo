/// Server-owned subscription state for a provider workspace.
///
/// The Flutter client never grants a plan from a checkout redirect and never
/// carries authoritative prices. It renders `plan_entitlements` and the
/// provider row that Supabase returns after Stripe's webhook has processed.
library;

enum SubscriptionTier {
  free,
  pro,
  enterprise;

  static SubscriptionTier parse(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'pro' => SubscriptionTier.pro,
      'enterprise' => SubscriptionTier.enterprise,
      _ => SubscriptionTier.free,
    };
  }

  String get wireName => name;

  String get displayName => switch (this) {
    SubscriptionTier.free => 'Free',
    SubscriptionTier.pro => 'Pro',
    SubscriptionTier.enterprise => 'Enterprise',
  };
}

enum SubscriptionStatus {
  none,
  trialing,
  active,
  pastDue,
  canceled,
  incomplete;

  static SubscriptionStatus parse(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'trialing' => SubscriptionStatus.trialing,
      'active' => SubscriptionStatus.active,
      'past_due' => SubscriptionStatus.pastDue,
      'canceled' || 'cancelled' => SubscriptionStatus.canceled,
      'incomplete' => SubscriptionStatus.incomplete,
      _ => SubscriptionStatus.none,
    };
  }

  String get displayName => switch (this) {
    SubscriptionStatus.none => 'Included',
    SubscriptionStatus.trialing => 'Trial',
    SubscriptionStatus.active => 'Active',
    SubscriptionStatus.pastDue => 'Past due',
    SubscriptionStatus.canceled => 'Canceled',
    SubscriptionStatus.incomplete => 'Incomplete',
  };
}

class SubscriptionPlan {
  final SubscriptionTier tier;

  /// Null means unlimited. Values come from `plan_entitlements`.
  final int? aiMonthlyQuota;
  final int? seatLimit;
  final bool workspaceEnabled;
  final bool purchasable;
  final double monthlyPriceUsd;
  final DateTime? updatedAt;

  const SubscriptionPlan({
    required this.tier,
    required this.aiMonthlyQuota,
    required this.seatLimit,
    required this.workspaceEnabled,
    required this.purchasable,
    required this.monthlyPriceUsd,
    this.updatedAt,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    int? nullableInt(Object? value) => value is num
        ? value.toInt()
        : value == null
        ? null
        : int.tryParse(value.toString());
    double money(Object? value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    return SubscriptionPlan(
      tier: SubscriptionTier.parse(map['plan']),
      aiMonthlyQuota: nullableInt(
        map['ai_monthly_quota'] ?? map['aiMonthlyQuota'],
      ),
      seatLimit: nullableInt(map['seat_limit'] ?? map['seatLimit']),
      workspaceEnabled:
          (map['workspace_enabled'] ?? map['workspaceEnabled']) == true,
      purchasable: map['purchasable'] == true,
      monthlyPriceUsd: money(map['price_usd_month'] ?? map['monthlyPriceUsd']),
      updatedAt: DateTime.tryParse(
        (map['updated_at'] ?? map['updatedAt'] ?? '').toString(),
      )?.toUtc(),
    );
  }

  String get priceLabel {
    if (monthlyPriceUsd == 0) return r'$0';
    final decimals = monthlyPriceUsd == monthlyPriceUsd.roundToDouble() ? 0 : 2;
    return '\$${monthlyPriceUsd.toStringAsFixed(decimals)}';
  }

  String get aiLabel => aiMonthlyQuota == null
      ? 'Unlimited AI actions'
      : '$aiMonthlyQuota AI actions per month';

  String get seatsLabel => seatLimit == null
      ? 'Unlimited seats'
      : seatLimit == 1
      ? '1 workspace seat'
      : '$seatLimit workspace seats';
}

class ProviderSubscription {
  final String providerId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? currentPeriodEnd;
  final bool foundingCoach;
  final bool hasStripeCustomer;

  const ProviderSubscription({
    required this.providerId,
    required this.tier,
    required this.status,
    required this.currentPeriodEnd,
    required this.foundingCoach,
    required this.hasStripeCustomer,
  });

  const ProviderSubscription.free()
    : providerId = '',
      tier = SubscriptionTier.free,
      status = SubscriptionStatus.none,
      currentPeriodEnd = null,
      foundingCoach = false,
      hasStripeCustomer = false;

  factory ProviderSubscription.fromMap(Map<String, dynamic> map) {
    final customer = map['stripe_customer_id'] ?? map['stripeCustomerId'];
    return ProviderSubscription(
      providerId: (map['id'] ?? map['_id'] ?? '').toString(),
      tier: SubscriptionTier.parse(map['plan']),
      status: SubscriptionStatus.parse(map['plan_status'] ?? map['planStatus']),
      currentPeriodEnd: DateTime.tryParse(
        (map['plan_period_end'] ?? map['planPeriodEnd'] ?? '').toString(),
      )?.toUtc(),
      foundingCoach: (map['founding_coach'] ?? map['foundingCoach']) == true,
      hasStripeCustomer: customer != null && customer.toString().isNotEmpty,
    );
  }

  /// Access is derived from server state, never from a checkout query string.
  bool hasEntitlementAt(DateTime now) {
    if (tier == SubscriptionTier.free) return true;
    if (status == SubscriptionStatus.active ||
        status == SubscriptionStatus.trialing) {
      return true;
    }
    if (status == SubscriptionStatus.pastDue && currentPeriodEnd != null) {
      return now.toUtc().isBefore(currentPeriodEnd!);
    }
    return false;
  }

  /// The tier whose features may be used right now. A stale paid-plan value is
  /// never presented as active after its server-confirmed entitlement ends.
  SubscriptionTier effectiveTierAt(DateTime now) =>
      hasEntitlementAt(now) ? tier : SubscriptionTier.free;

  bool get canManageBilling => hasStripeCustomer;
}

class BillingException implements Exception {
  final String message;
  const BillingException(this.message);

  @override
  String toString() => message;
}
