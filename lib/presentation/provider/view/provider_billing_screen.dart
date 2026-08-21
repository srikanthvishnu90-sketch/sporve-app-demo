import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/subscription.dart';
import '../../../core/services/sentry_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/billing_controller.dart';

class ProviderBillingScreen extends StatefulWidget {
  const ProviderBillingScreen({super.key});

  @override
  State<ProviderBillingScreen> createState() => _ProviderBillingScreenState();
}

class _ProviderBillingScreenState extends State<ProviderBillingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BillingController>().load();
    });
  }

  Uri _returnUri(String result) {
    return Uri.base.replace(
      queryParameters: {...Uri.base.queryParameters, 'billing': result},
    );
  }

  Future<void> _startCheckout(SubscriptionTier tier) async {
    final controller = context.read<BillingController>();
    final uri = await controller.startCheckout(
      plan: tier,
      successUrl: _returnUri('returned'),
      cancelUrl: _returnUri('canceled'),
    );
    if (!mounted || uri == null) return;
    try {
      final launched = await launchUrl(uri, webOnlyWindowName: '_self');
      if (!launched && mounted) _showLaunchError();
    } catch (error, stackTrace) {
      await SentryService().captureException(
        error,
        stackTrace: stackTrace,
        hint: 'Stripe subscription checkout URL launch failed',
      );
      if (mounted) _showLaunchError();
    }
  }

  Future<void> _openPortal() async {
    final controller = context.read<BillingController>();
    final uri = await controller.openPortal(returnUrl: _returnUri('portal'));
    if (!mounted || uri == null) return;
    try {
      final launched = await launchUrl(uri, webOnlyWindowName: '_self');
      if (!launched && mounted) _showLaunchError();
    } catch (error, stackTrace) {
      await SentryService().captureException(
        error,
        stackTrace: stackTrace,
        hint: 'Stripe billing portal URL launch failed',
      );
      if (mounted) _showLaunchError();
    }
  }

  void _showLaunchError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The Stripe billing page could not open.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BillingController>();
    final subscription = controller.subscription;
    final returned = kIsWeb ? Uri.base.queryParameters['billing'] : null;

    return GradientScaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.slateText,
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.lg,
              AppSizes.screenPadding,
              AppSizes.xxxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: AppSizes.xxl),
                      Text(
                        'Choose the plan that fits your workspace',
                        style: AppTypography.display.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: Text(
                          'Start free, move to Pro when you need more capacity, '
                          'or follow Enterprise as shared workspace support '
                          'becomes available.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.xl),
                      _subscriptionPolicy(),
                      if (returned != null) ...[
                        const SizedBox(height: AppSizes.md),
                        _returnNotice(returned),
                      ],
                      const SizedBox(height: AppSizes.md),
                      if (subscription != null)
                        _currentPlanSummary(subscription, controller.acting)
                      else
                        _notice(
                          controller.loading
                              ? 'Loading your server-confirmed plan…'
                              : 'Your current workspace plan is unavailable.',
                          controller.loading
                              ? Icons.sync_rounded
                              : Icons.info_outline_rounded,
                        ),
                      if (!kIsWeb) ...[
                        const SizedBox(height: AppSizes.md),
                        _notice(
                          'Plan purchases and changes are not available in '
                          'this mobile app. Your server-confirmed access is '
                          'still shown here.',
                          Icons.phone_iphone_rounded,
                        ),
                      ],
                      const SizedBox(height: AppSizes.xxl),
                      _plansHeading(controller.loading),
                      const SizedBox(height: AppSizes.md),
                      if (controller.error != null) ...[
                        _errorCard(controller.error!, controller.load),
                        const SizedBox(height: AppSizes.md),
                      ],
                      if (controller.loading && controller.plans.isEmpty)
                        _planSkeletons()
                      else if (controller.plans.isNotEmpty)
                        _plansLayout(
                          controller.plans,
                          subscription,
                          controller.acting,
                        )
                      else if (controller.error == null)
                        _notice(
                          'No plan definitions are available right now.',
                          Icons.info_outline_rounded,
                        ),
                      const SizedBox(height: AppSizes.xl),
                      _billingFootnote(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      SporveIconButton(
        Icons.arrow_back_rounded,
        circle: true,
        iconSize: 20,
        onTap: () => Navigator.maybePop(context),
      ),
      const SizedBox(width: AppSizes.lg),
      Expanded(
        child: Text(
          'Plan & billing',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  Widget _subscriptionPolicy() => Semantics(
    label:
        'Sporve is subscription funded and takes zero percent from bookings.',
    child: Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairlineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.slateTint,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: const Icon(
              Icons.percent_rounded,
              color: AppColors.slateText,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sporve takes 0% from bookings',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  'Your workspace subscription funds Sporve. Stripe '
                  'processing and connected-account payout costs remain '
                  'separate.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _returnNotice(String returned) {
    return switch (returned) {
      'returned' => _notice(
        'Checkout returned. Access changes only after Stripe confirms '
        'payment and the server updates this workspace.',
        Icons.sync_rounded,
      ),
      'canceled' => _notice(
        'Checkout was closed. Your existing plan is unchanged.',
        Icons.info_outline_rounded,
      ),
      'portal' => _notice(
        'Billing management returned. Pull to refresh if Stripe is still '
        'processing a change.',
        Icons.sync_rounded,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _currentPlanSummary(ProviderSubscription subscription, bool acting) {
    final entitled = subscription.hasEntitlementAt(DateTime.now());
    final effectiveTier = subscription.effectiveTierAt(DateTime.now());
    final period = _formatDate(subscription.currentPeriodEnd);
    final previousPaidPlan = effectiveTier != subscription.tier;

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your workspace',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Wrap(
                spacing: AppSizes.sm,
                runSpacing: AppSizes.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${effectiveTier.displayName} plan',
                    style: AppTypography.h1.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  _statusChip(subscription.status.displayName, entitled),
                ],
              ),
              if (previousPaidPlan) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  '${subscription.tier.displayName} billing is '
                  '${subscription.status.displayName.toLowerCase()}; access '
                  'has returned to Free.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warmAccent,
                  ),
                ),
              ] else if (period != null &&
                  subscription.tier != SubscriptionTier.free) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  'Current access period ends $period.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (subscription.foundingCoach) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  'Founding coach billing benefit is applied by Stripe.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.slateText,
                  ),
                ),
              ],
            ],
          );
          final manage = kIsWeb && subscription.canManageBilling
              ? SporveButton(
                  'Manage subscription',
                  onPressed: acting ? null : _openPortal,
                  loading: acting,
                  variant: SporveButtonVariant.dark,
                  size: SporveButtonSize.compact,
                  fullWidth: constraints.maxWidth < 620,
                  icon: Icons.open_in_new_rounded,
                )
              : null;

          if (manage == null) return details;
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: AppSizes.lg),
                manage,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: details),
              const SizedBox(width: AppSizes.xl),
              manage,
            ],
          );
        },
      ),
    );
  }

  Widget _plansHeading(bool loading) => Row(
    children: [
      Expanded(
        child: Text(
          'Available plans',
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
        ),
      ),
      Text(
        'Monthly billing',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      if (loading) ...[
        const SizedBox(width: AppSizes.sm),
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.slateText,
          ),
        ),
      ],
    ],
  );

  Widget _plansLayout(
    List<SubscriptionPlan> plans,
    ProviderSubscription? subscription,
    bool acting,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: [
              for (var i = 0; i < plans.length; i++) ...[
                _planCard(plans[i], subscription, acting),
                if (i != plans.length - 1) const SizedBox(height: AppSizes.md),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < plans.length; i++) ...[
                Expanded(child: _planCard(plans[i], subscription, acting)),
                if (i != plans.length - 1) const SizedBox(width: AppSizes.md),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _planCard(
    SubscriptionPlan plan,
    ProviderSubscription? subscription,
    bool acting,
  ) {
    final effectiveTier = subscription?.effectiveTierAt(DateTime.now());
    final isCurrent = plan.tier == effectiveTier;
    final recommended = plan.tier == SubscriptionTier.pro && !isCurrent;
    final enterprisePending =
        plan.tier == SubscriptionTier.enterprise && !plan.workspaceEnabled;

    return Semantics(
      container: true,
      label: '${plan.tier.displayName} plan, ${plan.priceLabel} per month',
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: recommended ? AppColors.surface2 : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isCurrent || recommended
                ? AppColors.slateBorder
                : AppColors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  plan.tier.displayName,
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isCurrent)
                  _statusChip('Current', true)
                else if (recommended)
                  _statusChip('Recommended', true)
                else if (enterprisePending)
                  _statusChip('Early access', false),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    plan.priceLabel,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.xs),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '/ month',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              _planDescription(plan.tier),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Divider(color: AppColors.hairline, height: 1),
            const SizedBox(height: AppSizes.lg),
            _feature(plan.aiLabel),
            const SizedBox(height: AppSizes.sm),
            _feature(
              enterprisePending
                  ? 'Unlimited seats when shared workspaces launch'
                  : plan.seatsLabel,
              available: !enterprisePending,
            ),
            const SizedBox(height: AppSizes.sm),
            _feature('0% Sporve booking fee'),
            if (enterprisePending) ...[
              const SizedBox(height: AppSizes.sm),
              _feature(
                'Shared workspace access is not enabled yet',
                available: false,
              ),
            ],
            const SizedBox(height: AppSizes.lg),
            _planAction(plan, subscription, isCurrent, acting),
          ],
        ),
      ),
    );
  }

  Widget _planAction(
    SubscriptionPlan plan,
    ProviderSubscription? subscription,
    bool isCurrent,
    bool acting,
  ) {
    if (isCurrent) {
      return SporveButton(
        'Current plan',
        onPressed: null,
        variant: SporveButtonVariant.dark,
        size: SporveButtonSize.compact,
      );
    }

    if (!kIsWeb) {
      return _availabilityLine(
        Icons.phone_iphone_rounded,
        'Plan changes are unavailable in this app.',
      );
    }

    final activePaidPlan =
        subscription != null &&
        subscription.effectiveTierAt(DateTime.now()) != SubscriptionTier.free;
    if (activePaidPlan || plan.tier == SubscriptionTier.free) {
      if (subscription?.canManageBilling == true) {
        return SporveButton(
          'Manage current plan',
          onPressed: acting ? null : _openPortal,
          loading: acting,
          variant: SporveButtonVariant.dark,
          size: SporveButtonSize.compact,
          icon: Icons.open_in_new_rounded,
        );
      }
      return _availabilityLine(
        Icons.info_outline_rounded,
        'Load an active billing profile to change plans.',
      );
    }

    if (!plan.purchasable || plan.tier == SubscriptionTier.enterprise) {
      return _availabilityLine(
        Icons.schedule_rounded,
        'Not available for self-serve purchase yet.',
      );
    }

    return SporveButton(
      'Upgrade to ${plan.tier.displayName}',
      onPressed: acting ? null : () => _startCheckout(plan.tier),
      loading: acting,
      size: SporveButtonSize.compact,
    );
  }

  String _planDescription(SubscriptionTier tier) => switch (tier) {
    SubscriptionTier.free => 'For a solo provider getting started.',
    SubscriptionTier.pro =>
      'For active coaches who need more AI capacity and seats.',
    SubscriptionTier.enterprise =>
      'For organizations preparing for shared workspace access.',
  };

  Widget _feature(String text, {bool available = true}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          available ? Icons.check_rounded : Icons.schedule_rounded,
          color: available ? AppColors.slateText : AppColors.textTertiary,
          size: 16,
        ),
      ),
      const SizedBox(width: AppSizes.sm),
      Expanded(
        child: Text(
          text,
          style: AppTypography.bodySmall.copyWith(
            color: available ? AppColors.textSecondary : AppColors.textTertiary,
          ),
        ),
      ),
    ],
  );

  Widget _availabilityLine(IconData icon, String text) => SizedBox(
    height: 44,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 18),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _planSkeletons() => Column(
    children: [
      for (var i = 0; i < 3; i++) ...[
        Container(
          height: 222,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBar(82),
              const SizedBox(height: AppSizes.lg),
              _skeletonBar(132),
              const SizedBox(height: AppSizes.xl),
              _skeletonBar(double.infinity),
              const SizedBox(height: AppSizes.sm),
              _skeletonBar(210),
            ],
          ),
        ),
        if (i != 2) const SizedBox(height: AppSizes.md),
      ],
    ],
  );

  Widget _skeletonBar(double width) => Container(
    width: width,
    height: 13,
    decoration: BoxDecoration(
      color: AppColors.surface3,
      borderRadius: BorderRadius.circular(AppRadii.chip),
    ),
  );

  Widget _billingFootnote() => Text(
    'Plan definitions and access come from Supabase. Paid checkout and '
    'subscription management are hosted by Stripe. Returning from checkout '
    'does not grant access before the server confirms the subscription.',
    textAlign: TextAlign.center,
    style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
  );

  Widget _notice(String message, IconData icon) => Container(
    padding: const EdgeInsets.all(AppSizes.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.slateText),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _errorCard(String message, Future<void> Function() retry) => Container(
    padding: const EdgeInsets.all(AppSizes.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      border: Border.all(color: AppColors.hairlineStrong),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );

  Widget _statusChip(String label, bool positive) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: positive ? AppColors.slateTint : AppColors.warmTint,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      border: Border.all(
        color: positive ? AppColors.slateBorder : AppColors.warmAccent,
      ),
    ),
    child: Text(
      label,
      style: AppTypography.font(
        color: positive ? AppColors.slateText : AppColors.warmAccent,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  String? _formatDate(DateTime? value) {
    if (value == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}
