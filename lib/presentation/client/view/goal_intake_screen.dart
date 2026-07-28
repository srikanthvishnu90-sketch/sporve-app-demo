import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ambient_surface.dart';
import '../controllers/goal_intake_provider.dart';
import '../controllers/plan_provider.dart';

/// **Prompt 2 — conversational goal intake.** Reuses the AI-chat surface (same
/// deep-black canvas, drifting slate aurora, S badge, gradient input pill as
/// `AiAssistantScreen`) so intake feels like the concierge, not a form. Scripted
/// by [GoalIntakeProvider]: ≤4 questions, each with tappable chips PLUS free
/// text, a live inline-editable summary card, and a Confirm that creates the
/// goal + plan and asks the engine for proposals. "Just browse trainers" is
/// always one tap away (outcome-first, never forced).
class GoalIntakeScreen extends StatefulWidget {
  const GoalIntakeScreen({super.key});

  @override
  State<GoalIntakeScreen> createState() => _GoalIntakeScreenState();
}

class _GoalIntakeScreenState extends State<GoalIntakeScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _summaryOutcome = TextEditingController();
  bool _summaryHydrated = false;

  // First-session priming (spec §9): if proposal generation runs long, cover
  // the wait with an honest interstitial; if it returns in <2s, never show it.
  bool _priming = false;
  Timer? _primingTimer;

  // Chat-surface identity via design tokens (slate/obsidian). The drifting
  // aurora keeps the sanctioned AI-surface treatment as slate-alpha washes.
  static const _bg = AppColors.ink;
  static const _aurora1 = Color(0x807692AE); // slate wash
  static const _aurora2 = Color(0x61475569); // deep-slate wash
  static const _greeting = AppColors.textPrimary;
  static const _betaLabel = AppColors.textSecondary;
  static const _topIcon = AppColors.textTertiary;
  static const _logoText = AppColors.slateText;
  static const _logoBg = Color(0x387692AE);
  static const _logoBorder = Color(0x8C7692AE);
  static const _logoGlow = Color(0x597692AE);
  static const _pillBg = AppColors.surface;
  static const _inputText = AppColors.textPrimary;
  static const _placeholder = AppColors.textTertiary;
  static const _userBubble = Color(0x2E7692AE);
  static const _chipFill = Color(0x147692AE);
  static const _chipOn = Color(0x557692AE);
  static const _accent = AppColors.slate;

  // Concierge chatbox accents — a faint spectrum over the slate glow ("very
  // little" orange/blue/green). Blue is the AI cue (apt for the concierge),
  // green/orange add life; all low-alpha so the canvas stays black.
  static const _glowBlue = Color(0x552E7BFF);
  static const _glowGreen = Color(0x3334C759);
  static const _glowOrange = Color(0x33E8A33A);

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalIntakeProvider>().start(
        athleteId: (args['athleteId'] ?? '').toString(),
        athleteName: args['athleteName']?.toString(),
        sport: args['sport']?.toString(),
      );
    });
  }

  @override
  void dispose() {
    _primingTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    _summaryOutcome.dispose();
    super.dispose();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final v = _input.text.trim();
    if (v.isEmpty) return;
    final p = context.read<GoalIntakeProvider>();
    switch (p.step) {
      case 0:
        p.answerOutcome(v);
        break;
      case 1:
        p.answerTimelineText(v);
        break;
      case 2:
        p.answerBudgetText(v);
        break;
      case 3:
        p.finishConstraints(v);
        break;
    }
    _input.clear();
    _scrollToBottomSoon();
  }

  Future<void> _confirm() async {
    final p = context.read<GoalIntakeProvider>();
    // Show the priming interstitial only if confirm is STILL running at ~2s —
    // a fast return skips it entirely and lands straight on Plan (spec §9).
    _primingTimer?.cancel();
    _primingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _priming = true);
    });
    await p.confirm();
    _primingTimer?.cancel();
    if (!mounted) return;
    if (p.done) {
      // Refresh the Plan home so it lands on the new goal + proposals.
      await context.read<PlanProvider>().load();
      if (!mounted) return;
      Get.back();
    } else {
      // Anything other than success uncovers the summary so the parent can retry.
      setState(() => _priming = false);
      if (p.error != null) {
        Get.snackbar(
          'Goal',
          p.error!,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          backgroundColor: AppColors.surface2,
          colorText: _greeting,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GoalIntakeProvider>();
    if (p.messages.isNotEmpty) _scrollToBottomSoon();

    return AmbientSurface(
      baseColor: _bg,
      focal: const Alignment(0, -0.9),
      radius: 1.4,
      glowOpacity: 0.035,
      counterGlow: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned(
              left: -140,
              top: -170,
              child: _aurora(460, 400, _aurora1),
            ),
            Positioned(left: 30, top: -210, child: _aurora(400, 340, _aurora2)),
            SafeArea(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(child: _thread(p)),
                  if (p.atSummary) _summaryCard(p) else _composer(p),
                ],
              ),
            ),
            if (_priming) Positioned.fill(child: _primingOverlay()),
          ],
        ),
      ),
    );
  }

  // Interstitial covering slow proposal generation — the three-proposal /
  // you-approve-everything promise, stated honestly (spec §9).
  Widget _primingOverlay() => Container(
    color: _bg.withValues(alpha: 0.92),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 36),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sBadge(),
        const SizedBox(height: 24),
        Text(
          "We're finding your first matches",
          textAlign: TextAlign.center,
          style: AppTypography.font(
            color: _greeting,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          "We'll suggest up to three background-check-verified options that fit the goal and "
          'budget. You approve everything — nothing books without you.',
          textAlign: TextAlign.center,
          style: AppTypography.font(
            color: _betaLabel,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(_accent),
          ),
        ),
      ],
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Get.back(),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.arrow_back, color: _topIcon, size: 20),
          ),
        ),
        _betaChip(),
        const Spacer(),
        // Always visible — outcome-first, never forced into intake.
        GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.findCoach),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Text(
              'Just browse trainers',
              style: AppTypography.font(color: _betaLabel, fontSize: 11.5),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _thread(GoalIntakeProvider p) => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    itemCount: p.messages.length,
    itemBuilder: (context, i) {
      final m = p.messages[i];
      return m.fromUser ? _userBubbleRow(m.text) : _conciergeBubbleRow(m.text);
    },
  );

  Widget _userBubbleRow(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 44),
    child: Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _userBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: const Color(0x557692AE)),
        ),
        child: Text(
          text,
          style: AppTypography.font(
            color: _greeting,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    ),
  );

  Widget _conciergeBubbleRow(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, right: 32),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sBadge(),
        const SizedBox(width: 9),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _pillBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Text(
              text,
              style: AppTypography.font(
                color: _greeting,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Composer: quick-reply chips for the current step + free-text pill ──────
  Widget _composer(GoalIntakeProvider p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Wrap(spacing: 8, runSpacing: 8, children: _chipsForStep(p)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: _inputPill(p),
        ),
      ],
    );
  }

  List<Widget> _chipsForStep(GoalIntakeProvider p) {
    switch (p.step) {
      case 0:
        return [
          _chip(
            'Make a team',
            () => p.answerOutcome('Make a team', type: 'make_team'),
          ),
          _chip(
            'Get better at the game',
            () => p.answerOutcome(
              'Get better at the game',
              type: 'skill_development',
            ),
          ),
          _chip(
            'Stay active and love it',
            () =>
                p.answerOutcome('Stay active and love it', type: 'fitness_fun'),
          ),
          _chip(
            'Go as far as possible',
            () =>
                p.answerOutcome('Go as far as possible', type: 'elite_pathway'),
          ),
        ];
      case 1:
        return [
          _chip(
            'This season',
            () => p.answerTimeline('This season', date: _plusDays(120)),
          ),
          _chip(
            'By next year',
            () => p.answerTimeline('By next year', date: _nextAug()),
          ),
          _chip('No rush', () => p.answerTimeline('No rush', date: null)),
        ];
      case 2:
        return [
          _chip('~\$100/mo', () => p.answerBudget('~\$100/mo', cents: 10000)),
          _chip('~\$300/mo', () => p.answerBudget('~\$300/mo', cents: 30000)),
          _chip('~\$500+/mo', () => p.answerBudget('~\$500+/mo', cents: 50000)),
          _chip('Skip', () => p.answerBudget('Not specified', cents: null)),
        ];
      case 3:
        final weekend = ['Sat', 'Sun'];
        final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
        return [
          _chip(
            'Weekends',
            () => p.toggleDaySet(weekend, 'Weekends'),
            on: weekend.every(p.days.contains),
          ),
          _chip(
            'Weekdays',
            () => p.toggleDaySet(weekday, 'Weekdays'),
            on: weekday.every(p.days.contains),
          ),
          _chip(
            'In-person',
            () => p.setSessionType('in_person'),
            on: p.sessionTypePref == 'in_person',
          ),
          _chip(
            'Virtual',
            () => p.setSessionType('virtual'),
            on: p.sessionTypePref == 'virtual',
          ),
          _chip("That's everything", () => p.finishConstraints(), solid: true),
        ];
      default:
        return const [];
    }
  }

  Widget _chip(
    String text,
    VoidCallback onTap, {
    bool on = false,
    bool solid = false,
  }) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: solid ? _accent : (on ? _chipOn : _chipFill),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: on || solid
              ? const Color(0x8C7692AE)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Text(
        text,
        style: AppTypography.font(
          color: solid ? Colors.white : _betaLabel,
          fontSize: 12.5,
          fontWeight: on || solid ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );

  Widget _inputPill(GoalIntakeProvider p) => Container(
    // Faint tri-color glow bleeding out from behind the pill — blue at the left,
    // green under, orange at the right. Very low alpha; the black canvas holds.
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(26)),
      boxShadow: [
        BoxShadow(
          color: _glowBlue,
          blurRadius: 24,
          spreadRadius: -8,
          offset: Offset(-10, -2),
        ),
        BoxShadow(
          color: _glowGreen,
          blurRadius: 22,
          spreadRadius: -10,
          offset: Offset(0, 6),
        ),
        BoxShadow(
          color: _glowOrange,
          blurRadius: 24,
          spreadRadius: -8,
          offset: Offset(10, -2),
        ),
      ],
    ),
    child: Container(
      padding: const EdgeInsets.all(1.4),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(26)),
        // Border sweeps blue → slate → green → orange, faintly.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x662E7BFF),
            Color(0x407692AE),
            Color(0x3334C759),
            Color(0x33E8A33A),
          ],
          stops: [0.0, 0.4, 0.72, 1.0],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _pillBg,
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              cursorColor: _logoText,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              style: AppTypography.font(color: _inputText, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                hintText: _hintForStep(p.step),
                hintStyle: AppTypography.font(
                  color: _placeholder,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendText,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _accent,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
      ),
    ),
  );

  String _hintForStep(int step) {
    switch (step) {
      case 0:
        return 'Type the goal in your words';
      case 1:
        return 'e.g. by 2027, or "no rush"';
      case 2:
        return 'e.g. 300, or skip';
      default:
        return 'Anything else? (optional)';
    }
  }

  // ── Live, inline-editable summary card ─────────────────────────────────────
  Widget _summaryCard(GoalIntakeProvider p) {
    // Hydrate the editable outcome field once when the summary first appears.
    if (!_summaryHydrated) {
      _summaryOutcome.text = p.outcomeText;
      _summaryHydrated = true;
    }
    // Pinned to the bottom of the screen (it replaces the composer at the base
    // of the Column) and rendered as a surface-2 sheet — the raised-drawer step
    // in the obsidian stack — so it reads as a summary drawer, not a card.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x557692AE)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR PLAN',
              style: AppTypography.font(
                color: _placeholder,
                fontSize: 10.5,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            _summaryOutcomeField(p),
            const SizedBox(height: 12),
            _summaryRow('Sport', p.sport, () => _editSport(p)),
            _summaryRow('Timeline', p.targetLabel, () => _editTimeline(p)),
            _summaryRow('Budget', p.budgetLabel, () => _editBudget(p)),
            _summaryRow('Preferences', _prefsLabel(p), null),
            _summaryRadius(p),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.findCoach),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        'Browse instead',
                        style: AppTypography.font(
                          color: _betaLabel,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: p.submitting ? null : _confirm,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: p.submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Confirm & build plan',
                              style: AppTypography.font(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'I only propose — you approve every booking.',
                style: AppTypography.font(color: _placeholder, fontSize: 10.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryOutcomeField(GoalIntakeProvider p) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: TextField(
      controller: _summaryOutcome,
      onChanged: p.editOutcome,
      maxLines: 2,
      minLines: 1,
      cursorColor: _logoText,
      style: AppTypography.font(color: _greeting, fontSize: 16, height: 1.3),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        hintText: 'Your goal',
        hintStyle: AppTypography.font(color: _placeholder, fontSize: 16),
      ),
    ),
  );

  Widget _summaryRow(String label, String value, VoidCallback? onEdit) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: AppTypography.font(color: _placeholder, fontSize: 12.5),
              ),
            ),
            Expanded(
              // Captured fields render in Data-S mono (tabular figures) so the
              // parent scans the values honestly (spec §2 / decision #15).
              child: Text(
                value,
                style: AppTypography.mono(size: 13, color: _greeting),
              ),
            ),
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.edit_outlined,
                  color: _topIcon,
                  size: 16,
                ),
              ),
          ],
        ),
      );

  // Explicit travel-radius selector (default 40km) → constraints.max_distance_km.
  Widget _summaryRadius(GoalIntakeProvider p) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            'Travel radius',
            style: AppTypography.font(color: _placeholder, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: _accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
              thumbColor: _accent,
              overlayColor: _chipOn,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: p.maxDistanceKm,
              min: 5,
              max: 80,
              divisions: 15,
              onChanged: p.setMaxDistanceKm,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${p.maxDistanceKm.round()} km',
            textAlign: TextAlign.right,
            style: AppTypography.mono(size: 13, color: _greeting),
          ),
        ),
      ],
    ),
  );

  String _prefsLabel(GoalIntakeProvider p) {
    final parts = <String>[];
    if (p.days.isNotEmpty) parts.add(p.days.join('/'));
    if (p.sessionTypePref != 'any') {
      parts.add(p.sessionTypePref == 'in_person' ? 'in-person' : 'virtual');
    }
    return parts.isEmpty ? 'No preference' : parts.join(' · ');
  }

  Future<void> _editSport(GoalIntakeProvider p) async {
    final ctrl = TextEditingController(text: p.sport);
    final v = await _promptText('Sport', ctrl);
    if (v != null) p.editSport(v);
  }

  void _editTimeline(GoalIntakeProvider p) {
    _pickSheet('Timeline', [
      _SheetOption(
        'This season',
        () => p.setTarget(_plusDays(120), 'This season'),
      ),
      _SheetOption(
        'By next year',
        () => p.setTarget(_nextAug(), 'By next year'),
      ),
      _SheetOption('No rush', () => p.setTarget(null, 'No target date')),
    ]);
  }

  void _editBudget(GoalIntakeProvider p) {
    _pickSheet('Monthly budget', [
      _SheetOption('~\$100/mo', () => p.setBudget(10000, '~\$100/mo')),
      _SheetOption('~\$300/mo', () => p.setBudget(30000, '~\$300/mo')),
      _SheetOption('~\$500+/mo', () => p.setBudget(50000, '~\$500+/mo')),
      _SheetOption('Not specified', () => p.setBudget(null, 'Not specified')),
    ]);
  }

  Future<String?> _promptText(String title, TextEditingController ctrl) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text(
          title,
          style: AppTypography.font(color: _greeting, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: _logoText,
          style: AppTypography.font(color: _greeting, fontSize: 14),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _pickSheet(String title, List<_SheetOption> options) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: AppTypography.font(
                    color: _placeholder,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            for (final o in options)
              ListTile(
                title: Text(
                  o.label,
                  style: AppTypography.font(color: _greeting, fontSize: 15),
                ),
                onTap: () {
                  o.onTap();
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _plusDays(int days) {
    final d = DateTime.now().add(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _nextAug() {
    final y = DateTime.now().year + 1;
    return '$y-08-01';
  }

  Widget _sBadge() => Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _logoBg,
      border: Border.all(color: _logoBorder),
      boxShadow: const [BoxShadow(color: _logoGlow, blurRadius: 14)],
    ),
    child: Image.asset(
      AppAssets.appLogo,
      width: 15,
      height: 15,
      color: _logoText,
      colorBlendMode: BlendMode.srcIn,
    ),
  );

  Widget _betaChip() => Container(
    padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sBadge(),
        const SizedBox(width: 8),
        Text(
          'Concierge',
          style: AppTypography.font(color: _betaLabel, fontSize: 11.5),
        ),
      ],
    ),
  );

  Widget _aurora(double w, double h, Color c) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
    child: Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [c, c.withValues(alpha: 0)],
          stops: const [0.0, 0.72],
        ),
      ),
    ),
  );
}

class _SheetOption {
  final String label;
  final VoidCallback onTap;
  _SheetOption(this.label, this.onTap);
}
