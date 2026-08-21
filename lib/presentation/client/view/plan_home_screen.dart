import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/utils/session_time.dart';
import '../../../core/utils/provider_trust.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import '../controllers/plan_provider.dart';
import '../../authentication/controllers/auth_provider.dart';
import 'messages_screen.dart';

/// **Plan home** — the athlete's goal-driven dashboard, laid out to the approved
/// reference: SPORVE top bar → the outcome as a display headline + phase-progress
/// bar (filled in the goal's SPORT color) → UP NEXT session card (glyph tile,
/// schedule, location, Message) → PROGRESS strip → SUGGESTED FOR THE GOAL (a
/// horizontal rail of AI-matched trainer cards) → Browse all trainers. The
/// concierge PROPOSES; every Approve runs the existing booking + payment flow.
/// Colors are ours (obsidian canvas + slate chrome via AppColors); the per-sport
/// accent carries the goal's identity. Everything shown is grounded in a real row.
class PlanHomeScreen extends StatefulWidget {
  const PlanHomeScreen({super.key});

  @override
  State<PlanHomeScreen> createState() => _PlanHomeScreenState();
}

class _PlanHomeScreenState extends State<PlanHomeScreen> {
  bool _navigating = false; // debounce entries into the booking flow

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlanProvider>().load();
    });
  }

  // The goal's sport drives the accent (progress bar, glyph, Approve). A single
  // known sport → its bright color; a multi-sport / general goal → bright white.
  Color get _sportColor {
    final s = (context.read<PlanProvider>().goal?['sport'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    const multi = {
      '',
      'general',
      'multi',
      'multi-sport',
      'multisport',
      'multiple',
      'all',
      'all-around',
      'various',
    };
    if (multi.contains(s)) return AppColors.textPrimary; // bright white
    return SportColors.of(s);
  }

  void _openIntake(PlanProvider p) {
    final a = p.athlete;
    final sports = a?['preferredSports'];
    Get.toNamed(
      AppRoutes.goalIntake,
      arguments: {
        'athleteId': a?['_id']?.toString() ?? '',
        'athleteName': (a?['firstName'] ?? a?['fullName'])?.toString(),
        'sport': (sports is List && sports.isNotEmpty)
            ? sports.first.toString()
            : null,
      },
    )?.then((_) {
      if (mounted) context.read<PlanProvider>().load();
    });
  }

  void _approve(Map<String, dynamic> proposal) {
    // Auth-on-action (spec §3.2) + intent preservation (§3.3.3): the WHOLE
    // approve→book action is the requireAuth closure, so a guest who verifies
    // resumes straight into the booking flow instead of re-tapping Approve. The
    // navigation debounce lives inside the closure — a bounced guest never gets
    // stuck with _navigating true, since the closure only runs once authed.
    context.read<AuthProvider>().requireAuth(() {
      if (_navigating) return; // ignore rapid double-taps into the booking flow
      _navigating = true;
      final program = proposal['program'];
      if (program is Map) {
        final prov = program['providerId'];
        final coach =
            (prov is Map ? prov['businessName'] : null)?.toString() ??
            (proposal['provider'] is Map
                ? proposal['provider']['businessName']?.toString()
                : null) ??
            'Academy';
        Get.toNamed(
          AppRoutes.bookingFlow,
          arguments: {
            'program': Map<String, dynamic>.from(program),
            'title': program['title'],
            'coach': coach,
            'price': program['price'],
            'planProposalId': proposal['_id'],
          },
        )?.then((_) {
          _navigating = false;
          if (mounted) context.read<PlanProvider>().load();
        });
      } else {
        Get.toNamed(AppRoutes.findCoach)?.then((_) => _navigating = false);
      }
    });
  }

  void _viewProgram(Map<String, dynamic> program) =>
      Get.toNamed(AppRoutes.sessionDetails, arguments: program);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlanProvider>();
    return GradientScaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.slateText,
          backgroundColor: AppColors.surface,
          onRefresh: () => p.load(),
          child: _body(p),
        ),
      ),
    );
  }

  Widget _body(PlanProvider p) {
    if (p.loading && !p.loadedOnce) {
      return _fill(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.slateText),
            strokeWidth: 3,
          ),
        ),
      );
    }
    if (p.error != null && !p.hasGoal) return _fill(_errorState(p));
    // Guests can't own a goal — invite them to sign in before the no-goal state.
    final auth = context.watch<AuthProvider>();
    if (!auth.isVerified) return _fill(_guestInvitation(p));
    if (!p.hasGoal) return _fill(_noGoalInvitation(p));
    return _planLayout(p);
  }

  Widget _fill(Widget child) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.72, child: child),
    ],
  );

  // ── The reference layout ───────────────────────────────────────────────────
  Widget _planLayout(PlanProvider p) {
    final proposals = p.proposals;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: _hero(p),
        ),
        const SizedBox(height: 24),
        _section('UP NEXT', _upNext(p), pad: true),
        const SizedBox(height: 28),
        _section('PROGRESS', _progressCard(p), pad: true),
        const SizedBox(height: 28),
        // Suggested rail bleeds to the right edge, like the reference.
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: _sectionLabel('SUGGESTED FOR THE GOAL'),
        ),
        const SizedBox(height: 12),
        _suggestedRail(proposals),
        const SizedBox(height: 28),
        _browseLink(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Hero: outcome headline + phase subtitle + progress bar ──────────────────
  Widget _hero(PlanProvider p) {
    final phases = p.phaseNames;
    final current = p.currentPhaseIndex.clamp(
      0,
      phases.isEmpty ? 0 : phases.length - 1,
    );
    final fill = phases.isEmpty ? 0.0 : (current + 1) / phases.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.headline.isEmpty ? 'Your outcome' : p.headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.h1.copyWith(
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _heroSubtitle(p, phases, current),
          style: AppTypography.mono(
            color: AppColors.textSecondary,
            size: 12,
            weight: FontWeight.w500,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fill == 0 ? null : fill,
            minHeight: 5,
            backgroundColor: AppColors.hairlineStrong,
            valueColor: AlwaysStoppedAnimation<Color>(_sportColor),
          ),
        ),
      ],
    );
  }

  String _heroSubtitle(PlanProvider p, List<String> phases, int current) {
    final parts = <String>[];
    final t = p.targetDate;
    if (t != null && t.isNotEmpty) {
      final d = DateTime.tryParse(t);
      if (d != null) parts.add('By ${_monthFull(d)} ${d.year}');
    }
    if (phases.isNotEmpty) {
      parts.add('Phase ${current + 1} of ${phases.length}: ${phases[current]}');
    }
    return parts.join('  ·  ');
  }

  // ── UP NEXT ─────────────────────────────────────────────────────────────────
  Widget _upNext(PlanProvider p) {
    final booking = p.nextBooking;
    if (booking != null) return _upNextFromBooking(booking, p);
    final top = p.topProposal;
    if (top != null) return _upNextFromProposal(top);
    return _card(
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_empty,
            color: AppColors.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Finding your first matches — check back shortly.',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _upNextFromBooking(Map<String, dynamic> booking, PlanProvider p) {
    final session = booking['sessionId'];
    final title =
        (session is Map ? session['title'] : null)?.toString() ??
        'Upcoming session';
    final start = session is Map ? parseSessionStart(session) : null;
    final when = start == null
        ? null
        : '${_weekday(start)} ${formatTime12h(start)}';
    final loc = _locationOf(booking) ?? _locationOf(session);
    return _upNextShell(
      title: title,
      when: when,
      location: loc,
      primaryLabel: 'Message',
      onPrimary: () => Get.to(() => const MessagesScreen()),
    );
  }

  Widget _upNextFromProposal(Map<String, dynamic> prop) {
    final program = prop['program'] is Map
        ? Map<String, dynamic>.from(prop['program'] as Map)
        : <String, dynamic>{};
    final coach = _coachOf(program);
    final title = (program['title']?.toString().isNotEmpty ?? false)
        ? '${program['title']} with $coach'
        : 'Next session with $coach';
    final price = _priceLabel(program);
    final loc = _locationOf(program);
    return _upNextShell(
      title: title,
      when: price,
      location: loc,
      primaryLabel: 'Message',
      onPrimary: () => Get.to(() => const MessagesScreen()),
    );
  }

  Widget _upNextShell({
    required String title,
    String? when,
    String? location,
    required String primaryLabel,
    required VoidCallback onPrimary,
  }) {
    final accent = _sportColor;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: accent.withValues(alpha: 0.30)),
                ),
                child: Icon(
                  SportColors.iconOf(
                    context.read<PlanProvider>().goal?['sport']?.toString(),
                  ),
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (when != null && when.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _metaLine(Icons.schedule, when),
                    ],
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _metaLine(Icons.location_on_outlined, location),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.slate,
                foregroundColor: AppColors.onSlate,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
              child: Text(
                primaryLabel.toUpperCase(),
                style: AppTypography.mono(
                  color: AppColors.onSlate,
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: AppColors.textSecondary, size: 15),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.mono(color: AppColors.textPrimary, size: 12.5),
        ),
      ),
    ],
  );

  // ── PROGRESS ────────────────────────────────────────────────────────────────
  Widget _progressCard(PlanProvider p) {
    final digest = p.digest;
    final body = digest?['body']?.toString();
    final count = digest?['sessionsCounted'];
    final hasCount = count is int && count > 0;
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasCount
                      ? '$count session${count == 1 ? '' : 's'} done'
                      : 'Your progress starts here',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (body == null || body.isEmpty)
                      ? 'First session will start your progress.'
                      : body,
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.trending_up, color: _sportColor, size: 34),
        ],
      ),
    );
  }

  // ── SUGGESTED FOR THE GOAL — horizontal trainer rail ────────────────────────
  Widget _suggestedRail(List<Map<String, dynamic>> proposals) {
    if (proposals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No suggestions yet — the concierge is still looking.',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              SporveButton(
                'Browse trainers',
                icon: Icons.search,
                fullWidth: false,
                size: SporveButtonSize.compact,
                variant: SporveButtonVariant.secondary,
                onPressed: () => Get.toNamed(AppRoutes.findCoach),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 316,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: proposals.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _trainerCard(proposals[i]),
      ),
    );
  }

  Widget _trainerCard(Map<String, dynamic> prop) {
    final program = prop['program'] is Map
        ? Map<String, dynamic>.from(prop['program'] as Map)
        : <String, dynamic>{};
    final sport = program['sportType']?.toString();
    final accent = SportColors.of(sport);
    final coach = _coachOf(program);
    final img =
        (program['image'] ??
                program['coverImage'] ??
                (program['providerId'] is Map
                    ? program['providerId']['profileImage']
                    : null))
            ?.toString() ??
        '';
    final hasRating =
        program['averageRating'] is num &&
        (program['averageRating'] as num) > 0;
    final ratingPrice = [
      if (hasRating) program['averageRating'].toString(),
      ?_priceLabel(program),
    ].join('  ·  ');
    final dist = _distanceLabel(program);
    final why = (prop['reasonText'] ?? '').toString();
    final verified = providerTrusted(program);

    return GestureDetector(
      onTap: () => _viewProgram(program),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo (or a sport-tinted glyph header when there's no image).
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (img.isNotEmpty)
                    SporveImage(
                      img,
                      fit: BoxFit.cover,
                      fallbackIcon: SportColors.iconOf(sport),
                    )
                  else
                    Container(
                      color: accent.withValues(alpha: 0.12),
                      alignment: Alignment.center,
                      child: Icon(
                        SportColors.iconOf(sport),
                        color: accent.withValues(alpha: 0.55),
                        size: 56,
                      ),
                    ),
                  if (verified)
                    Positioned(top: 10, right: 10, child: _proBadge()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          coach.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ratingPrice,
                        style: AppTypography.mono(
                          color: accent,
                          size: 12.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (dist != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      dist,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    why.isEmpty ? 'Matched to your goal.' : '"$why"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _viewProgram(program),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(
                              color: AppColors.hairlineStrong,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.chip,
                              ),
                            ),
                          ),
                          child: Text(
                            'VIEW',
                            style: AppTypography.mono(
                              color: AppColors.textPrimary,
                              size: 11,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _approve(prop),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: SportColors.onColorOf(sport),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.chip,
                              ),
                            ),
                          ),
                          child: Text(
                            'APPROVE',
                            style: AppTypography.mono(
                              color: SportColors.onColorOf(sport),
                              size: 11,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadii.chip),
      border: Border.all(color: AppColors.trustGold.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified, color: AppColors.trustGold, size: 13),
        const SizedBox(width: 4),
        Text(
          'PRO',
          style: AppTypography.mono(
            color: AppColors.textPrimary,
            size: 10,
            weight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _browseLink() => Center(
    child: TextButton.icon(
      onPressed: () => Get.toNamed(AppRoutes.findCoach),
      icon: Text(
        'BROWSE ALL TRAINERS',
        style: AppTypography.mono(
          color: AppColors.textSecondary,
          size: 12,
          weight: FontWeight.w500,
        ),
      ),
      label: const Icon(
        Icons.arrow_forward,
        color: AppColors.textSecondary,
        size: 18,
      ),
    ),
  );

  // ── No-goal / error states ──────────────────────────────────────────────────
  Widget _noGoalInvitation(PlanProvider p) {
    final hasAthlete = p.athlete != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.slateTint,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: AppColors.slateText,
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasAthlete ? "What's the goal?" : 'Start with your athlete',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasAthlete
                ? 'Tell the concierge what you’re working toward and it will build a '
                      'plan and suggest coaches — you approve every step.'
                : 'Add a child to your profile, then set an outcome and the concierge '
                      'will build a plan around it.',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (hasAthlete)
            SporveButton(
              'Set a goal',
              icon: Icons.auto_awesome,
              variant: SporveButtonVariant.primary,
              onPressed: () => _openIntake(p),
            )
          else
            SporveButton(
              'Go to profile',
              icon: Icons.person_outline,
              variant: SporveButtonVariant.primary,
              onPressed: () => Get.toNamed(AppRoutes.editProfile),
            ),
          const SizedBox(height: 12),
          SporveButton(
            'Browse trainers',
            icon: Icons.search,
            variant: SporveButtonVariant.secondary,
            onPressed: () => Get.toNamed(AppRoutes.findCoach),
          ),
        ],
      ),
    );
  }

  // Guest (unverified) invitation — sign in before setting a goal. No sport
  // color, progress bar, or phase text here: there's no goal to ground them yet.
  Widget _guestInvitation(PlanProvider p) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.slateTint,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: const Icon(
            Icons.flag_outlined,
            color: AppColors.slateText,
            size: 26,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Set your athlete's goal",
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in and tell the concierge what you’re working toward — it '
          'builds a plan and suggests coaches, and you approve every step.',
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        SporveButton(
          'Get started',
          variant: SporveButtonVariant.primary,
          onPressed: () => Get.toNamed(AppRoutes.authEntry),
        ),
        const SizedBox(height: 12),
        SporveButton(
          'Browse trainers',
          variant: SporveButtonVariant.secondary,
          onPressed: () => Get.toNamed(AppRoutes.findCoach),
        ),
      ],
    ),
  );

  Widget _errorState(PlanProvider p) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          color: AppColors.textTertiary,
          size: 40,
        ),
        const SizedBox(height: 16),
        Text(
          p.error ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SporveButton(
          'Retry',
          fullWidth: false,
          variant: SporveButtonVariant.secondary,
          onPressed: () => p.load(),
        ),
      ],
    ),
  );

  // ── Shared bits ─────────────────────────────────────────────────────────────
  Widget _section(String label, Widget child, {bool pad = false}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: pad ? 20 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_sectionLabel(label), const SizedBox(height: 12), child],
    ),
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: AppTypography.mono(
      color: AppColors.textSecondary,
      size: 11,
      weight: FontWeight.w500,
    ).copyWith(letterSpacing: 1.6),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: AppColors.hairline),
    ),
    child: child,
  );

  // ── Grounded helpers ────────────────────────────────────────────────────────
  String _coachOf(Map<String, dynamic> program) {
    final prov = program['providerId'];
    final biz = prov is Map ? prov['businessName']?.toString() : null;
    if (biz != null && biz.isNotEmpty) return biz;
    final title = program['title']?.toString();
    return (title != null && title.isNotEmpty) ? title : 'A suggested coach';
  }

  String? _priceLabel(Map<String, dynamic>? program) {
    if (program == null) return null;
    final price = program['price'];
    if (price is num && price > 0) return '\$${price.round()}';
    return null;
  }

  String? _locationOf(dynamic src) {
    if (src is! Map) return null;
    final addr = src['address'];
    if (addr is Map) {
      final city = addr['city']?.toString();
      if (city != null && city.isNotEmpty) return city;
    }
    final prov = src['providerId'];
    if (prov is Map) {
      final biz = prov['businessName']?.toString();
      if (biz != null && biz.isNotEmpty) return biz;
    }
    return null;
  }

  String? _distanceLabel(Map<String, dynamic>? program) {
    final km = context.read<PlanProvider>().distanceKmForProgram(program);
    if (km == null) return null;
    return '${km.round()} km away';
  }

  static const _monthsFull = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String _monthFull(DateTime d) => _monthsFull[d.month - 1];
  String _weekday(DateTime d) => _weekdays[d.weekday - 1];
}
