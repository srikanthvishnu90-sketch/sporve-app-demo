import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/ui/ambient_surface.dart';
import '../controllers/setup_interview_controller.dart';

/// Provider Model Rebuild — item #4. The coach's setup, run as an AI INTERVIEW
/// (NOT a form, NOT a new nav tab). Reuses the goal-intake chat surface style
/// (deep-black canvas, drifting slate aurora, S badge, gradient input pill): the
/// agent asks 6–8 short questions with tappable chips PLUS free text, then shows
/// ONE editable summary the coach confirms. On confirm the controller calls the
/// existing item-#1 repo methods (createService × N, setWeeklyAvailability,
/// saveCoachPolicies) — the coach is live in minimal taps. Background check runs
/// async; this never blocks on it.
class SetupInterviewScreen extends StatefulWidget {
  const SetupInterviewScreen({super.key});

  @override
  State<SetupInterviewScreen> createState() => _SetupInterviewScreenState();
}

class _SetupInterviewScreenState extends State<SetupInterviewScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  // Chat-surface identity via design tokens (slate AI treatment, per goal-intake).
  static const _bg = AppColors.ink;
  static const _aurora1 = Color(0x807692AE);
  static const _aurora2 = Color(0x61475569);
  static const _greeting = AppColors.textPrimary;
  static const _sub = AppColors.textSecondary;
  static const _topIcon = AppColors.textTertiary;
  static const _logoText = AppColors.slateText;
  static const _logoBg = Color(0x387692AE);
  static const _logoBorder = Color(0x8C7692AE);
  static const _logoGlow = Color(0x597692AE);
  static const _pillBg = AppColors.surface;
  static const _placeholder = AppColors.textTertiary;
  static const _userBubble = Color(0x2E7692AE);
  static const _chipFill = Color(0x147692AE);
  static const _chipOn = Color(0x557692AE);
  static const _accent = AppColors.slate;
  static const _glowBlue = Color(0x552E7BFF);
  static const _glowGreen = Color(0x3334C759);
  static const _glowOrange = Color(0x33E8A33A);

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<SetupInterviewController>()
          .start(sport: args['sport']?.toString());
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
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
    final p = context.read<SetupInterviewController>();
    switch (p.step) {
      case 0:
        p.answerSport(v);
        break;
      case 1:
        p.answerKindsText(v);
        break;
      case 2:
        p.answerDurationText(v);
        break;
      case 3:
        p.answerPriceText(v);
        break;
      case 5:
        p.answerLocation(v);
        break;
      case 6:
        p.answerCancellation(v);
        break;
      case 7:
        unawaited(p.answerWhatToBring(v));
        break;
    }
    _input.clear();
    _scrollToBottomSoon();
  }

  Future<void> _confirm() async {
    final bool? agreed = await showDialog<bool>(
      context: context,
      builder: (dctx) {
        bool checked = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            title: Text(
              'Coach Safety Attestation',
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To protect athletes and coaches, Sporve requires agreement to observable-session standards:',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.slateText,
                  value: checked,
                  onChanged: (val) {
                    setDialogState(() => checked = val ?? false);
                  },
                  title: Text(
                    'I agree to observable-session norms: parents may observe all sessions, sessions take place in public/approved venues, and no private transportation of minors.',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: Text(
                  'Cancel',
                  style: AppTypography.font(color: AppColors.textTertiary),
                ),
              ),
              TextButton(
                onPressed: checked ? () => Navigator.pop(dctx, true) : null,
                child: Text(
                  'Confirm & Launch',
                  style: AppTypography.font(
                    color: checked
                        ? AppColors.slateText
                        : AppColors.textTertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (agreed != true || !mounted) return;
    final p = context.read<SetupInterviewController>();
    final ok = await p.confirm();
    if (!mounted) return;
    if (ok) {
      Get.snackbar(
        'You\'re set up',
        'Your first service is live. Safety attestation confirmed.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.surface2,
        colorText: _greeting,
      );
      Get.back(result: true);
    } else if (p.error != null) {
      Get.snackbar(
        'Setup',
        p.error!,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.surface2,
        colorText: _greeting,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SetupInterviewController>();
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
            Positioned(left: -140, top: -170, child: _aurora(460, 400, _aurora1)),
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
          ],
        ),
      ),
    );
  }

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
            _agentChip(),
          ],
        ),
      );

  Widget _thread(SetupInterviewController p) => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        itemCount: p.messages.length,
        itemBuilder: (context, i) {
          final m = p.messages[i];
          return m.fromUser ? _userBubbleRow(m.text) : _agentBubbleRow(m.text);
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
            child: Text(text,
                style: AppTypography.font(
                    color: _greeting, fontSize: 14, height: 1.4)),
          ),
        ),
      );

  Widget _agentBubbleRow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sBadge(),
            const SizedBox(width: 9),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _pillBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.07)),
                ),
                child: Text(text,
                    style: AppTypography.font(
                        color: _greeting, fontSize: 14, height: 1.45)),
              ),
            ),
          ],
        ),
      );

  // ── Composer: per-step chips + free-text pill ───────────────────────────────
  Widget _composer(SetupInterviewController p) => Column(
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

  List<Widget> _chipsForStep(SetupInterviewController p) {
    switch (p.step) {
      case 0:
        return [
          for (final s in ['Basketball', 'Soccer', 'Tennis', 'Baseball'])
            _chip(s, () => p.answerSport(s)),
        ];
      case 1:
        return [
          _chip('1-on-1 private', () => p.answerKinds(private: true, group: false)),
          _chip('Small groups', () => p.answerKinds(private: false, group: true)),
          _chip('Both', () => p.answerKinds(private: true, group: true),
              solid: true),
        ];
      case 2:
        return [
          for (final m in [30, 45, 60, 90])
            _chip('$m min', () => p.answerDuration(m),
                on: p.durationMinutes == m),
        ];
      case 3:
        final t = p.template.privateTemplate;
        final mid = t?.priceMidCents ?? p.privatePriceCents;
        return [
          _chip('${p.dollars(mid)} (typical)', () => p.answerPrice(mid),
              solid: true),
          for (final c in [6000, 8000, 10000])
            if (c != mid) _chip(p.dollars(c), () => p.answerPrice(c)),
        ];
      case 4:
        return [
          _chip('Weekday evenings', p.useWeekdayEvenings),
          _chip('Weekend mornings', p.useWeekendMornings),
          _chip('Both', p.useBothTimes, solid: true),
        ];
      case 5:
        return [
          _chip('Skip for now', p.skipLocation),
        ];
      case 6:
        return [
          _chip('Use the suggested policy', p.useTemplateCancellation,
              solid: true),
        ];
      case 7:
        return [
          _chip('Use the suggested list',
              () => unawaited(p.useTemplateWhatToBring()),
              solid: true),
        ];
      default:
        return const [];
    }
  }

  Widget _chip(String text, VoidCallback onTap,
          {bool on = false, bool solid = false}) =>
      GestureDetector(
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
          child: Text(text,
              style: AppTypography.font(
                color: solid ? Colors.white : _sub,
                fontSize: 12.5,
                fontWeight: on || solid ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
      );

  Widget _inputPill(SetupInterviewController p) => Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(26)),
          boxShadow: [
            BoxShadow(
                color: _glowBlue,
                blurRadius: 24,
                spreadRadius: -8,
                offset: Offset(-10, -2)),
            BoxShadow(
                color: _glowGreen,
                blurRadius: 22,
                spreadRadius: -10,
                offset: Offset(0, 6)),
            BoxShadow(
                color: _glowOrange,
                blurRadius: 24,
                spreadRadius: -8,
                offset: Offset(10, -2)),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(1.4),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(26)),
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
                color: _pillBg, borderRadius: BorderRadius.circular(25)),
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
                    style:
                        AppTypography.font(color: _greeting, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                      hintText: _hintForStep(p.step),
                      hintStyle: AppTypography.font(
                          color: _placeholder, fontSize: 14),
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
                    decoration:
                        const BoxDecoration(shape: BoxShape.circle, color: _accent),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 18),
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
        return 'Type your sport';
      case 1:
        return 'e.g. both';
      case 2:
        return 'e.g. 60';
      case 3:
        return 'e.g. 80';
      case 5:
        return 'Venue name, or skip';
      case 6:
        return 'e.g. 24-hour cancellation';
      case 7:
        return 'e.g. water and court shoes';
      default:
        return 'Type your answer';
    }
  }

  // ── Editable summary ────────────────────────────────────────────────────────
  Widget _summaryCard(SetupInterviewController p) => Padding(
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
              Row(
                children: [
                  Text('YOUR SETUP',
                      style: AppTypography.font(
                          color: _placeholder,
                          fontSize: 10.5,
                          letterSpacing: 1.2)),
                  const Spacer(),
                  if (p.refining)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_accent)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _serviceRow(p),
              const SizedBox(height: 6),
              _summaryRow('Duration', '${p.durationMinutes} min',
                  () => _editDuration(p)),
              _summaryRow('Availability', p.availabilityLabel(),
                  () => _editAvailability(p)),
              _summaryRow(
                  'Cancellation',
                  p.cancellationPolicy.isEmpty ? 'Not set' : p.cancellationPolicy,
                  () => _editText('Cancellation policy', p.cancellationPolicy,
                      p.setCancellationPolicy)),
              _summaryRow(
                  'What to bring',
                  p.whatToBring.isEmpty ? 'Not set' : p.whatToBring,
                  () => _editText(
                      'What to bring', p.whatToBring, p.setWhatToBring)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: p.submitting ? null : _confirm,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: _accent, borderRadius: BorderRadius.circular(12)),
                  child: p.submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white)),
                        )
                      : Text('Confirm & go live',
                          style: AppTypography.font(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'One shared calendar feeds every service. Your background check runs in the background.',
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.font(color: _placeholder, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _serviceRow(SetupInterviewController p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.offersPrivate)
            _servicePill('Private lesson', p.privatePriceCents, 'capacity 1',
                () => _editPrice('Private price', p.privatePriceCents,
                    p.setPrivatePrice)),
          if (p.offersGroup)
            _servicePill('Small-group', p.groupPriceCents,
                'up to ${p.groupCapacity}',
                () => _editPrice(
                    'Group price', p.groupPriceCents, p.setGroupPrice)),
        ],
      );

  Widget _servicePill(
          String title, int cents, String meta, VoidCallback onEdit) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.font(
                            color: _greeting,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(meta,
                        style: AppTypography.font(
                            color: _placeholder, fontSize: 11.5)),
                  ],
                ),
              ),
              Consumer<SetupInterviewController>(
                builder: (context, p, child) => Text(p.dollars(cents),
                    style: AppTypography.mono(size: 14, color: _greeting)),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.edit_outlined,
                    color: _topIcon, size: 16),
              ),
            ],
          ),
        ),
      );

  Widget _summaryRow(String label, String value, VoidCallback onEdit) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(label,
                  style:
                      AppTypography.font(color: _placeholder, fontSize: 12.5)),
            ),
            Expanded(
              child: Text(value,
                  style: AppTypography.font(
                      color: _greeting, fontSize: 13, height: 1.35)),
            ),
            GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child:
                  const Icon(Icons.edit_outlined, color: _topIcon, size: 16),
            ),
          ],
        ),
      );

  Future<void> _editPrice(
      String title, int current, void Function(int) apply) async {
    final ctrl = TextEditingController(text: (current / 100).round().toString());
    final v = await _promptText(title, ctrl, keyboardDigits: true);
    if (v != null) {
      final dollars = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
      if (dollars != null) apply(dollars * 100);
    }
  }

  void _editDuration(SetupInterviewController p) => _pickSheet('Session length', [
        for (final m in [30, 45, 60, 90])
          _SheetOption('$m minutes', () => p.setDuration(m)),
      ]);

  void _editAvailability(SetupInterviewController p) =>
      _pickSheet('Availability', [
        _SheetOption('Weekday evenings',
            () => p.setAvailabilityChoice('weekday')),
        _SheetOption('Weekend mornings',
            () => p.setAvailabilityChoice('weekend')),
        _SheetOption('Both', () => p.setAvailabilityChoice('both')),
      ]);

  Future<void> _editText(
      String title, String current, void Function(String) apply) async {
    final ctrl = TextEditingController(text: current);
    final v = await _promptText(title, ctrl);
    if (v != null) apply(v.trim());
  }

  Future<String?> _promptText(String title, TextEditingController ctrl,
      {bool keyboardDigits = false}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text(title,
            style: AppTypography.font(color: _greeting, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              keyboardDigits ? TextInputType.number : TextInputType.text,
          cursorColor: _logoText,
          style: AppTypography.font(color: _greeting, fontSize: 14),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
  }

  void _pickSheet(String title, List<_SheetOption> options) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: AppTypography.font(
                        color: _placeholder,
                        fontSize: 11,
                        letterSpacing: 1.0)),
              ),
            ),
            for (final o in options)
              ListTile(
                title: Text(o.label,
                    style:
                        AppTypography.font(color: _greeting, fontSize: 15)),
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
        child: Image.asset(AppAssets.appLogo,
            width: 15,
            height: 15,
            color: _logoText,
            colorBlendMode: BlendMode.srcIn),
      );

  Widget _agentChip() => Container(
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
            Text('Setup assistant',
                style: AppTypography.font(color: _sub, fontSize: 11.5)),
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
  _SheetOption(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}
