import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../onboarding/controllers/onboarding_controller.dart';
import '../widgets/create_listing_bottom_sheet.dart';
import '../widgets/create_trainer_bottom_sheet.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final controller = context.read<ProviderController>();
    controller.fetchMyPrograms();
    controller.fetchProviderBookings();
    controller.loadTrainers(); // roster (Booksy model)
    // Pull the latest provider row first (reflects any prior write-back).
    await controller.fetchProviderProfile();
    if (!mounted) return;
    // Returning from Stripe onboarding lands back here via a full page reload.
    // If an account exists but charges aren't active yet, RE-INVOKE the function
    // so it retrieves the (now-onboarded) account and writes
    // stripe_charges_enabled back — then the re-fetch reflects the live status.
    // A plain re-fetch alone can never refresh charges; only the function writes
    // it. Self-limiting: once charges are active this no longer fires.
    if (controller.stripeAccountId != null &&
        !controller.stripeChargesEnabled) {
      await _refreshPayoutsFromStripe(controller);
    }
  }

  /// Re-invoke the onboarding function purely for its write-back side effect
  /// (retrieve account → persist stripe_charges_enabled). The returned
  /// onboarding URL is intentionally ignored — we are not redirecting here.
  Future<void> _refreshPayoutsFromStripe(ProviderController controller) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'stripe-connect-onboarding',
        body: {'returnUrl': Uri.base.origin},
      );
    } on FunctionException catch (e) {
      debugPrint('refresh payouts -> ${e.status} ${e.details}');
    } catch (e) {
      debugPrint('refresh payouts -> $e');
    }
    if (!mounted) return;
    await controller.fetchProviderProfile();
  }

  void _showCreateListing(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateListingBottomSheet(),
    );
  }

  void _showCreateTrainer(BuildContext context, {Map<String, dynamic>? member}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTrainerBottomSheet(member: member),
    );
  }

  /// Starts Stripe Connect onboarding via the `stripe-connect-onboarding` Edge
  /// Function (invoke auto-attaches the signed-in user's JWT), then opens the
  /// returned onboarding URL — or reflects an already-active account.
  Future<void> _handleSetupPayouts(BuildContext context) async {
    final controller = context.read<ProviderController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'stripe-connect-onboarding',
        body: {'returnUrl': Uri.base.origin},
      );
      final data = (res.data as Map?) ?? {};
      if (data['error'] != null) {
        debugPrint('stripe-connect-onboarding ${data['error']}');
        _payoutsSnack(messenger, data['error'].toString(), ok: false);
        return;
      }
      final onboardingUrl = data['onboardingUrl'] as String?;
      final chargesEnabled = data['chargesEnabled'] == true;
      if (onboardingUrl != null && onboardingUrl.isNotEmpty) {
        // Open Stripe in a NEW top-level tab. Stripe Connect refuses to render
        // inside an iframe/embedded browser (X-Frame-Options), and '_blank'
        // escapes the app's frame so onboarding loads. Surface a real failure
        // instead of silently doing nothing if the launch is blocked.
        final launched = await launchUrl(
          Uri.parse(onboardingUrl),
          webOnlyWindowName: '_blank',
        );
        if (!launched) {
          _payoutsSnack(
            messenger,
            "Couldn't open Stripe. Allow pop-ups and open the app in a normal "
            'browser tab (not an embedded preview).',
            ok: false,
          );
        }
      } else if (chargesEnabled) {
        _payoutsSnack(messenger, 'Payouts active', ok: true);
        await controller.fetchProviderProfile();
      } else {
        _payoutsSnack(
          messenger,
          'Could not start payouts setup. Please try again.',
          ok: false,
        );
      }
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = (d is Map && d['error'] != null)
          ? d['error'].toString()
          : 'Payout setup error (status ${e.status})';
      debugPrint('FN stripe-connect-onboarding -> ${e.status} ${e.details}');
      _payoutsSnack(messenger, msg, ok: false);
    } catch (e) {
      debugPrint('FN stripe-connect-onboarding -> $e');
      _payoutsSnack(messenger, '$e', ok: false);
    }
  }

  void _payoutsSnack(
    ScaffoldMessengerState messenger,
    String msg, {
    required bool ok,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.positive : AppColors.negative,
      ),
    );
  }

  /// Payouts status row: active (slate check) or a "Set up payouts" button.
  Widget _buildPayoutsCard(
    BuildContext context,
    ProviderController controller,
  ) {
    final active = controller.stripeChargesEnabled;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYOUTS',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (active)
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.successGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payouts active',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'Connect a Stripe account to receive payouts from your bookings.',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SporveButton(
              'Set up payouts',
              onPressed: () => _handleSetupPayouts(context),
              variant: SporveButtonVariant.primary,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingProvider = context.watch<OnboardingProvider>();
    final providerController = context.watch<ProviderController>();
    final listings = providerController.listings;

    return GradientScaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.slateText,
          backgroundColor: AppColors.surface,
          onRefresh: () => Future.wait([
            providerController.fetchMyPrograms(),
            providerController.fetchProviderBookings(),
            providerController.fetchProviderProfile(),
          ]),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good morning',
                            style: AppTypography.font(
                              color: AppColors.textGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (providerController.providerProfile['businessName']
                                            as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? providerController
                                      .providerProfile['businessName']
                                : (onboardingProvider.institutionName.isNotEmpty
                                      ? onboardingProvider.institutionName
                                      : 'Your academy'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.slateText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Active • ${providerController.sessionsToday} sessions today',
                                style: AppTypography.font(
                                  color: AppColors.slateText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipOval(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: SporveImage(
                          '',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.person,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (!onboardingProvider.profileCompleted)
                  _buildFinishProfileCard(context, onboardingProvider),

                // Payouts (Stripe Connect) status / setup
                _buildPayoutsCard(context, providerController),

                // AI Front Office #10 — proactive post-session recap prompt: the
                // most recent completed session with a child surfaces a one-tap
                // "How did it go?" → the existing parent-update capture + rails.
                Builder(
                  builder: (_) {
                    final done = providerController.sessions
                        .where((s) =>
                            s.isCompleted && s.childFirstName.trim().isNotEmpty)
                        .toList()
                      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
                    if (done.isEmpty) return const SizedBox.shrink();
                    return _buildRecapPromptCard(context, done.first);
                  },
                ),

                // Summary Cards — computed from real bookings/listings.
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        label: 'REVENUE',
                        value:
                            '\$${providerController.revenue.toStringAsFixed(0)}',
                        trend: 'PAID',
                        trendColor: AppColors.warmAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        label: 'BOOKINGS',
                        value: '${providerController.bookingCount}',
                        trend: 'TOTAL',
                        trendColor: AppColors.warmAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        label: 'LISTINGS',
                        value: '${providerController.listingCount}',
                        trend: 'LIVE',
                        trendColor: AppColors.warmAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Insight Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY\'S INSIGHT',
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '"Providers with 5+ photos in their listing earn 2× more views per week."',
                              style: AppTypography.font(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.lightbulb_outline,
                            color: AppColors.slateText,
                            size: 32,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Today's Sessions
                Text(
                  'TODAY\'S SESSIONS',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                if (providerController.bookingsError)
                  ErrorRetry(
                    message:
                        "We couldn't load your sessions. Please try again.",
                    onRetry: () => providerController.fetchProviderBookings(),
                  )
                else if (providerController.sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No sessions scheduled.',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else ...[
                  for (final session in providerController.sessions.take(
                    2,
                  )) ...[
                    Builder(
                      builder: (context) {
                        final timeParts = session.timeStr.split(' ');
                        final timeVal = timeParts[0];
                        final periodVal = timeParts.length > 1
                            ? timeParts[1]
                            : 'PM';
                        return _buildSessionCard(
                          time: timeVal,
                          period: periodVal,
                          title: session.serviceTitle,
                          subtitle: session.userName.toUpperCase(),
                          status: session.isConfirmed ? 'CONFIRMED' : 'PENDING',
                          statusColor: session.isConfirmed
                              ? AppColors.successGreen
                              : AppColors.warmAccent,
                          sport: session.serviceTitle,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 20),

                // Active Listings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVE LISTINGS',
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SeeAll(
                      label: 'Manage',
                      onTap: () => Get.toNamed(AppRoutes.providerListings),
                    ),
                  ],
                ),
                if (providerController.isLoading &&
                    !providerController.listingsLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.slateText,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (providerController.listingsError)
                  ErrorRetry(
                    message:
                        "We couldn't load your listings. Please try again.",
                    onRetry: () => providerController.fetchMyPrograms(),
                  )
                else if (listings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          color: AppColors.textTertiary,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No active listings yet.\nTap below to create your first program.',
                          textAlign: TextAlign.center,
                          style: AppTypography.font(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  for (int i = 0; i < listings.length && i < 2; i++) ...[
                    _buildActiveListingCard(
                      index: i,
                      image: listings[i].image,
                      title: listings[i].title,
                      rating: listings[i].rating,
                      spots: listings[i].availability,
                      sport: listings[i].sportType,
                      context: context,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                // Create New Listing Button
                SporveButton(
                  'Create new listing',
                  onPressed: () => _showCreateListing(context),
                  variant: SporveButtonVariant.secondary,
                  icon: Icons.add,
                  onDark: true,
                ),

                // ── Trainers (Booksy model) ──────────────────────────────
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Trainers',
                        style: AppTypography.font(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    if (providerController.trainers.isNotEmpty)
                      Text('${providerController.trainers.length} on roster',
                          style: AppTypography.font(
                              fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Affiliated coaches families can book. You keep your set commission.',
                    style: AppTypography.font(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                if (!providerController.trainersLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (providerController.trainers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(
                        'No trainers yet. Add affiliated coaches and set the commission you keep on their bookings.',
                        style: AppTypography.font(
                            fontSize: 13, color: AppColors.textSecondary)),
                  )
                else
                  for (final m in providerController.trainers) ...[
                    _trainerTile(context, m),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 8),
                SporveButton(
                  'Create new trainer',
                  onPressed: () => _showCreateTrainer(context),
                  variant: SporveButtonVariant.secondary,
                  icon: Icons.person_add_alt_1,
                  onDark: true,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trainerTile(BuildContext context, Map<String, dynamic> m) {
    final p = (m['trainer_profile'] as Map?) ?? const {};
    final name = (p['display_name'] ?? 'Trainer').toString();
    final specialty = (p['specialty'] ?? p['bio'] ?? '').toString();
    final type = (m['commission_type'] ?? 'percent').toString();
    final val = (m['commission_value'] as num?)?.toDouble() ?? 0;
    final commission =
        type == 'percent' ? '${val.round()}% commission' : '\$${val.round()} / session';
    final verified = (m['background_check_status'] ?? 'none') == 'verified';
    return GestureDetector(
      onTap: () => _showCreateTrainer(context, member: m),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surface2,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTypography.font(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: AppTypography.font(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(specialty.isEmpty ? commission : '$specialty · $commission',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (verified ? AppColors.successGreen : AppColors.warmAccent)
                  .withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(verified ? 'Verified' : 'Pending',
                style: AppTypography.font(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: verified ? AppColors.successGreen : AppColors.warmAccent)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  // AI Front Office #10 — the coach-home recap prompt. One tap into the existing
  // parent-update capture (same args as the schedule's "Write parent update"),
  // which drafts (draft-recap / summarize) and Sends through the existing rails.
  Widget _buildRecapPromptCard(BuildContext context, ScheduledSession s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => Get.toNamed(
          AppRoutes.parentUpdate,
          arguments: {
            'bookingId': s.id,
            'childId': s.childId,
            'childFirstName': s.childFirstName,
            'sport': s.sport,
          },
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.slateTint,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.slateText, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How did it go with ${s.childFirstName}?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Three taps → a recap the parent will love.',
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward,
                  color: AppColors.slateText, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.mono(
              size: 20,
              weight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.arrow_upward, size: 8, color: trendColor),
              const SizedBox(width: 2),
              Text(
                trend,
                style: AppTypography.mono(
                  color: trendColor,
                  size: 11,
                  weight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard({
    required String time,
    required String period,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required String sport,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          SportIconTile(sport, size: 44), // sport color, not grey
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STARTS',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    time,
                    style: AppTypography.mono(
                      size: 20,
                      weight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    period,
                    style: AppTypography.mono(
                      size: 11,
                      weight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          OutlinePill(status, color: statusColor),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios,
            size: 10,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveListingCard({
    required int index,
    required String image,
    required String title,
    required String rating,
    required String spots,
    required String sport,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          // Sport-color tile instead of a grey image placeholder.
          if (image.isNotEmpty)
            SporveImage(
              image,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              radius: AppRadii.tile,
            )
          else
            SportIconTile(sport, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: AppColors.textPrimary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: AppTypography.mono(
                        size: 11,
                        weight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      spots,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SporveButton(
            'Edit',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    CreateListingBottomSheet(editIndex: index),
              );
            },
            variant: SporveButtonVariant.secondary,
            size: SporveButtonSize.compact,
            fullWidth: false,
          ),
        ],
      ),
    );
  }

  void _showFinishProfileModal(
    BuildContext context,
    OnboardingProvider provider,
  ) {
    int localCapacity = provider.maxAthletes;
    String localLogo = provider.logoPath ?? '';
    List<String> localGallery = List.from(provider.galleryPaths);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Complete Profile",
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SporveIconButton(
                            Icons.close,
                            color: AppColors.negative,
                            iconSize: 20,
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '1. MAX ATHLETES PER SESSION',
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.slateText,
                                inactiveTrackColor: AppColors.hairline,
                                thumbColor: AppColors.slateText,
                                trackHeight: 6,
                              ),
                              child: Slider(
                                value: localCapacity.toDouble(),
                                min: 1,
                                max: 100,
                                onChanged: (val) {
                                  setModalState(() {
                                    localCapacity = val.round();
                                  });
                                },
                              ),
                            ),
                          ),
                          Text(
                            '$localCapacity',
                            style: AppTypography.mono(
                              size: 20,
                              weight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '2. UPLOAD BRAND LOGO',
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setModalState(() {
                            localLogo = 'logo_mock.png';
                          });
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                localLogo.isNotEmpty
                                    ? Icons.check_circle
                                    : Icons.upload,
                                color: localLogo.isNotEmpty
                                    ? AppColors.slateText
                                    : AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                localLogo.isNotEmpty
                                    ? 'logo_mock.png uploaded!'
                                    : 'Upload Logo File',
                                style: AppTypography.font(
                                  color: localLogo.isNotEmpty
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '3. MEDIA GALLERY (ADD MOCK PHOTOS)',
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          if (localGallery.length < 4) {
                            setModalState(() {
                              localGallery.add(
                                'gallery_${localGallery.length + 1}.png',
                              );
                            });
                          }
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add Photo (${localGallery.length}/4)',
                                style: AppTypography.font(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (localGallery.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: localGallery
                              .map(
                                (p) => Chip(
                                  backgroundColor: AppColors.surface2,
                                  label: Text(
                                    p,
                                    style: AppTypography.font(
                                      color: AppColors.textPrimary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  onDeleted: () {
                                    setModalState(() {
                                      localGallery.remove(p);
                                    });
                                  },
                                  deleteIconColor: AppColors.textSecondary,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 32),
                      SporveButton(
                        'Save & finish',
                        onPressed: () {
                          provider.setMaxAthletes(localCapacity);
                          if (localLogo.isNotEmpty) {
                            provider.setLogo(localLogo);
                          }
                          for (var path in localGallery) {
                            if (!provider.galleryPaths.contains(path)) {
                              provider.addGalleryPhoto(path);
                            }
                          }
                          provider.setProfileCompleted(true);
                          Navigator.pop(context);
                          Get.snackbar(
                            'Profile Completed!',
                            'Your coach profile is now 100% complete!',
                            backgroundColor: AppColors.surface,
                            colorText: AppColors.textPrimary,
                          );
                        },
                        variant: SporveButtonVariant.primary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFinishProfileCard(
    BuildContext context,
    OnboardingProvider provider,
  ) {
    // Real completion signals from the onboarding profile — no fabricated count.
    final steps = <bool>[
      provider.institutionName.isNotEmpty,
      provider.selectedSports.isNotEmpty,
      (provider.logoPath ?? '').isNotEmpty,
      provider.galleryPaths.isNotEmpty,
    ];
    final completed = steps.where((s) => s).length;
    final total = steps.length;
    const barMaxWidth = 80.0;
    final barWidth = total == 0 ? 0.0 : barMaxWidth * (completed / total);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.slateBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.slateText,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  color: AppColors.onSlate,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Finish Your Profile',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Complete your capacity limits and media files so athletes can discover your program services.',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    height: 6,
                    width: barMaxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 6,
                      width: barWidth,
                      decoration: BoxDecoration(
                        color: AppColors.slateText,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed of $total completed',
                    style: AppTypography.font(
                      color: AppColors.slateText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SporveButton(
                'Complete Now',
                onPressed: () => _showFinishProfileModal(context, provider),
                variant: SporveButtonVariant.primary,
                size: SporveButtonSize.compact,
                fullWidth: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
