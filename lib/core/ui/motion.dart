import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Sporve motion system — the SINGLE source of truth for every animation in the
/// app (Part 2 of the motion spec). No screen or widget hardcodes its own
/// durations, curves, springs, scales, or haptics: pull them from here so the
/// whole app shares one motion language (WHOOP/Uber/Kalshi register — precise,
/// physical, restrained).
///
/// The five laws (Part 1): physics over duration · choreography over
/// simultaneity · the canvas never moves · motion is information · restraint
/// scales with frequency.
class Motion {
  Motion._();

  // ── Durations (fallback TWEENS: opacity / color only — NEVER position) ────
  /// Pressed-state color, ripple start.
  static const Duration instant = Duration(milliseconds: 80);

  /// Fades in/out of small elements.
  static const Duration fast = Duration(milliseconds: 140);

  /// Standard opacity / color transitions (nav select, tab indicator).
  static const Duration base = Duration(milliseconds: 220);

  /// Large-surface fades, scrim in/out.
  static const Duration slow = Duration(milliseconds: 320);

  /// One-time celebratory moments (booking confirmed).
  static const Duration hero = Duration(milliseconds: 450);

  // ── Easing (TWEENS only; never a symmetric easeInOut on anything visible) ─
  /// Emphasized decelerate — arrivals. Also exposed as [standard] so existing
  /// implicit widgets (AnimatedFoo) keep compiling with a spec-correct curve.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Accelerate out — exits are ~30% faster than entries; leaving feels lighter.
  static const Curve exit = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Back-compat alias for the default arrival curve (== [enter]).
  static const Curve standard = enter;

  /// Deprecated: overshoot curve. Use [Springs.bounce] for the ONE success
  /// overshoot; kept only so older references compile.
  @Deprecated('Use Springs.bounce (spring physics) for overshoot.')
  static const Curve emphasized = enter;

  // ── Springs (PRIMARY system — use for ALL spatial movement) ───────────────
  // A spring settling reads as engineered; a tween reads as PowerPoint.
  // Drive with [spring] / [springTo] below, never a bare Curves.bounceOut.

  /// Instant, no bounce — toggles, chips, small state flips.
  static const SpringDescription snap =
      SpringDescription(mass: 1, stiffness: 550, damping: 32);

  /// Quick, one subtle settle — cards, sheets, list items, most things.
  static const SpringDescription standardSpring =
      SpringDescription(mass: 1, stiffness: 380, damping: 28);

  /// Calm glide — large surfaces, page-level slides.
  static const SpringDescription gentle =
      SpringDescription(mass: 1, stiffness: 220, damping: 24);

  /// One visible overshoot — success moments ONLY (booking confirmed).
  static const SpringDescription bounce =
      SpringDescription(mass: 1, stiffness: 320, damping: 18);

  // ── Stagger & distances ───────────────────────────────────────────────────
  /// Delay between sibling arrivals in a cascade.
  static const Duration stagger = Duration(milliseconds: 24);

  /// Tighter cascade for utility grids (booking slots).
  static const Duration staggerTight = Duration(milliseconds: 16);

  /// Cap the cascade — items at or past this index all arrive together (a
  /// 20-item cascade is a loading screen, not choreography).
  static const int staggerCap = 8;

  static const double dMicro = 4; // chip select
  static const double dStandard = 12; // list / card entry
  static const double dSurface = 24; // sheet peek
  // Page distance is the surface width (100%) — handled per route.

  // ── Press ─────────────────────────────────────────────────────────────────
  /// Tap-down scale for pressable surfaces (universal touch acknowledgment).
  static const double pressScale = 0.96;

  /// Selected bottom-nav icon rise distance (px) and legacy scale.
  static const double navRise = 4;
  static const double iconActiveScale = 1.12;

  // ── Reduced motion ──────────────────────────────────────────────────────
  /// True when the platform/user requests reduced motion. Reduced motion means
  /// reduced AUTONOMOUS motion (springs collapse to [instant] fades, cascades
  /// collapse to simultaneous, blooms/sparkles skipped) — NOT reduced
  /// responsiveness (1:1 gesture tracking and press feedback always remain).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Stagger delay for sibling [index], honoring the cap and reduced motion.
  static Duration staggerDelay(
    int index, {
    bool reduced = false,
    Duration step = stagger,
  }) {
    if (reduced) return Duration.zero;
    return step * (index < staggerCap ? index : staggerCap);
  }

  /// Drive [controller] toward [target] on a spring (velocity-aware) — use this
  /// for EVERY spatial change instead of a tween. Optionally start [from] a
  /// value / [velocity]. Under [reduced] motion it collapses to an [instant]
  /// fade so autonomous movement disappears but state still resolves.
  static TickerFuture spring(
    AnimationController controller,
    SpringDescription spec, {
    double target = 1.0,
    double? from,
    double velocity = 0,
    bool reduced = false,
  }) {
    if (from != null) controller.value = from;
    if (reduced) {
      return controller.animateTo(target, duration: instant, curve: enter);
    }
    return controller.animateWith(
      SpringSimulation(spec, controller.value, target, velocity),
    );
  }
}

/// Motion's physical channel (Part 3.13 haptics map). ALWAYS paired with a
/// visual, NEVER fired alone — haptics on every tap = numbness, so card presses
/// intentionally use [Feel.none].
enum Feel {
  /// Card press — visual only, no haptic.
  none,

  /// Chip / toggle / slot select, swipe threshold cross.
  select,

  /// Booking confirmed (at the bloom peak) · payment success.
  confirm,

  /// Invalid / "no" action — paired with the 2px shake.
  error,

  /// Destructive confirm — the ONLY heavy impact in the app.
  destructive,
}

extension FeelHaptic on Feel {
  /// Perform this feel's haptic. Safe to call unconditionally; [Feel.none] is a
  /// no-op.
  void go() {
    switch (this) {
      case Feel.none:
        break;
      case Feel.select:
        HapticFeedback.selectionClick();
        break;
      case Feel.confirm:
        HapticFeedback.mediumImpact();
        break;
      case Feel.error:
        HapticFeedback.lightImpact();
        break;
      case Feel.destructive:
        HapticFeedback.heavyImpact();
        break;
    }
  }
}
