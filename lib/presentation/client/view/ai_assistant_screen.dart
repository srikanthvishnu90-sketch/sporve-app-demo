import 'dart:ui';
import '../../../core/ui/ambient_surface.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/matching/provider_matcher.dart';
import '../controllers/home_controller.dart';
import '../controllers/assistant_provider.dart';
import '../controllers/plan_provider.dart';

/// Sporve AI assistant chatbox — reached from "Ask a question" (AI Coach). A
/// live conversation backed by [AssistantProvider] (which routes to the
/// `ai-gateway` in prod, or a local heuristic on mock). Keeps the approved
/// visual identity: deep-black canvas, drifting slate aurora, beta chip,
/// gradient-bordered input pill.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  // Aurora surface palette (spec §12). Opaque members come from AppColors
  // tokens; the translucent glow/tint overlays stay inline (hook-exempt).
  static const _bg = AppColors.chatCanvas;
  static const _aurora1 = Color(0x806082A8);
  static const _aurora2 = Color(0x6148588A);
  static const _greeting = AppColors.chatTextBright;
  static const _betaLabel = AppColors.chatTextMuted;
  static const _topIcon = AppColors.chatIcon;
  static const _logoText = AppColors.chatLogoText;
  static const _logoBg = Color(0x386082A8);
  static const _logoBorder = Color(0x8C8CAFD2);
  static const _logoGlow = Color(0x5978A0C8);
  static const _pillBg = AppColors.chatSurface;
  static const _inputText = AppColors.chatInputText;
  static const _placeholder = AppColors.chatPlaceholder;
  static const _mic = AppColors.chatTextMuted;
  static const _disclaimer = AppColors.chatDisclaimer;
  static const _userBubble = Color(0x2E6082A8);
  static const _errorText = AppColors.chatError;

  /// Contextual suggestion pool derived from real state (decision #8); three
  /// are shown, rotating over the day so they feel alive rather than static.
  List<String> _suggestionsFor(PlanProvider plan) {
    final athlete = plan.athleteFirstName;
    final hasAthlete = athlete != 'Your athlete';
    final pool = <String>[
      if (plan.hasGoal)
        hasAthlete
            ? "When's $athlete's next session?"
            : "When's my next session?",
      if (plan.hasGoal) "How's progress this month?",
      'Find weekend options under \$75',
      'Show top-rated coaches near me',
      'How does booking work?',
    ];
    final start = pool.isEmpty ? 0 : DateTime.now().hour % pool.length;
    final count = pool.length < 3 ? pool.length : 3;
    return [for (var i = 0; i < count; i++) pool[(start + i) % pool.length]];
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final value = (text ?? _input.text).trim();
    if (value.isEmpty) return;
    context.read<AssistantProvider>().send(value);
    _input.clear();
    _scrollToBottomSoon();
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

  @override
  Widget build(BuildContext context) {
    final assistant = context.watch<AssistantProvider>();
    final profile = context.watch<HomeProvider>().userProfile;
    final plan = context.watch<PlanProvider>();
    final full = (profile?['firstName'] ?? profile?['name'] ?? '')
        .toString()
        .trim();
    final name = full.isEmpty ? 'there' : full.split(' ').first;
    if (assistant.messages.isNotEmpty || assistant.sending) {
      _scrollToBottomSoon();
    }

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
                  _topBar(assistant),
                  Expanded(
                    child: assistant.isEmpty
                        ? _emptyGreeting(name, _suggestionsFor(plan))
                        : _thread(assistant),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _inputPill()),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      // Permanent Caption disclaimer — exact copy (spec §12).
                      'AI assistant — not your coach. Answers can be wrong.',
                      textAlign: TextAlign.center,
                      style: AppTypography.font(
                        color: _disclaimer,
                        fontSize: 11,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(AssistantProvider assistant) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 20, 0),
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
        // "New chat" — clears the thread when there is one.
        GestureDetector(
          onTap: assistant.isEmpty
              ? null
              : () => context.read<AssistantProvider>().reset(),
          behavior: HitTestBehavior.opaque,
          child: Icon(
            Icons.edit_note_rounded,
            color: assistant.isEmpty
                ? _topIcon.withValues(alpha: 0.4)
                : _topIcon,
            size: 21,
          ),
        ),
      ],
    ),
  );

  Widget _emptyGreeting(String name, List<String> suggestions) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi $name — how can I help you train today?',
          style: AppTypography.font(
            color: _greeting,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in suggestions) _suggestionChip(s)],
        ),
      ],
    ),
  );

  Widget _suggestionChip(String text) => GestureDetector(
    onTap: () => _send(text),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        text,
        style: AppTypography.font(color: _betaLabel, fontSize: 12.5),
      ),
    ),
  );

  Widget _thread(AssistantProvider assistant) {
    final msgs = assistant.messages;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: msgs.length + (assistant.sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= msgs.length) return _typingBubble();
        final m = msgs[i];
        return m.isUser ? _userBubbleRow(m.text) : _assistantBubbleRow(m);
      },
    );
  }

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
          border: Border.all(color: const Color(0x556082A8)),
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

  Widget _assistantBubbleRow(AssistantMessage m) => Padding(
    padding: const EdgeInsets.only(bottom: 12, right: 32),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sBadge(),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _pillBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: m.isError
                        ? const Color(0x66E8899A)
                        : Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Text(
                  m.text,
                  style: AppTypography.font(
                    color: m.isError ? _errorText : _greeting,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
              for (final p in m.providers) _providerCard(p),
            ],
          ),
        ),
      ],
    ),
  );

  /// A tappable provider card under an answer — deep-links to the listing.
  Widget _providerCard(ProviderMatch m) {
    final dist = m.distanceKm != null ? '${m.distanceKm!.round()} km' : null;
    final c = SportColors.of(m.sport);
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.sessionDetails, arguments: m.raw),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pillBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(SportColors.iconOf(m.sport), color: c, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: _greeting,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Grounded: a real rating or an honest "New" — never "0★ (0)".
                    '${m.ratingCount > 0 ? '${m.ratingAvg}★ (${m.ratingCount})' : 'New'}${dist != null ? ' · $dist' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: _placeholder,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${m.priceDollars}',
              style: AppTypography.font(
                color: _greeting,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.chevron_right, color: _placeholder, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _typingBubble() => Padding(
    padding: const EdgeInsets.only(bottom: 12, right: 32),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sBadge(),
        const SizedBox(width: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          child: const _TypingDots(),
        ),
      ],
    ),
  );

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
    // The Sporve S logo (same size/placement as the old glyph), tinted to match.
    child: Image.asset(
      AppAssets.appLogo,
      width: 15,
      height: 15,
      color: _logoText,
      colorBlendMode: BlendMode.srcIn,
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
          'Beta v0.9',
          style: AppTypography.font(color: _betaLabel, fontSize: 11.5),
        ),
      ],
    ),
  );

  Widget _inputPill() => Container(
    padding: const EdgeInsets.all(1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0x8C8CAFD2),
          const Color(0x405A6EA0),
          Colors.white.withValues(alpha: 0.08),
        ],
        stops: const [0.0, 0.45, 1.0],
      ),
      boxShadow: const [BoxShadow(color: Color(0x296E96C8), blurRadius: 26)],
    ),
    child: Container(
      decoration: BoxDecoration(
        color: _pillBg,
        borderRadius: BorderRadius.circular(24),
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
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: AppTypography.font(color: _inputText, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                hintText: 'Ask about coaches or booking',
                hintStyle: AppTypography.font(
                  color: _placeholder,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Mic when empty (decorative), send arrow when there's text.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? () => _send() : null,
                behavior: HitTestBehavior.opaque,
                child: hasText
                    ? Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.chatAccent,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.mic_none_rounded,
                          color: _mic,
                          size: 18,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Three softly pulsing dots — the assistant "typing" indicator.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value - i * 0.2) % 1.0;
            final opacity = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.chatLogoText.withValues(alpha: opacity),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
