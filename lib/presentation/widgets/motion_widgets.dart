import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/ui/motion.dart';

/// The app's universal touch acknowledgment. On tap-down the child springs to
/// [pressedScale] on [Motion.snap] (real physics, not a tween); on release it
/// springs back. Fires [feel]'s haptic on tap. Use for ALL tappable surfaces so
/// every tap in the app feels identical.
///
/// [feel] defaults to [Feel.none] on purpose: CARD presses are visual only
/// (haptics on every tap = numbness — Part 3.13). Chips, toggles, nav items and
/// other selections should pass [Feel.select]; confirmations [Feel.confirm];
/// invalid actions [Feel.error]; destructive confirms [Feel.destructive].
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Feel feel;
  final HitTestBehavior behavior;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = Motion.pressScale,
    this.feel = Feel.none,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  // The controller's value IS the current scale; it rests at 1.0 and is unbounded
  // so a spring can transiently overshoot without clamping.
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _press(bool down) => Motion.spring(
    _c,
    Motion.snap,
    target: down ? widget.pressedScale : 1.0,
    reduced: Motion.reduced(context),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      enabled: enabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: GestureDetector(
          behavior: widget.behavior,
          onTapDown: enabled ? (_) => _press(true) : null,
          onTapUp: enabled ? (_) => _press(false) : null,
          onTapCancel: enabled ? () => _press(false) : null,
          onTap: enabled
              ? () {
                  widget.feel.go();
                  widget.onTap!();
                }
              : null,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) =>
                Transform.scale(scale: _c.value, child: child),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A single bottom-nav item. When selected, the icon tweens up to
/// [Motion.iconActiveScale] and to the active color (near-white textPrimary),
/// the label tweens to active color + weight; unselected items are muted
/// (textTertiary). Animates over [Motion.base]. Tapping presses + haptics via
/// [PressableScale]. Designed to sit directly in a Row (returns Expanded).
class AnimatedNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AnimatedNavItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        feel: Feel.select,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TweenAnimationBuilder<double>(
            duration: Motion.reduced(context) ? Duration.zero : Motion.base,
            curve: Motion.standard,
            tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
            builder: (context, t, _) {
              final color = Color.lerp(
                AppColors.textTertiary,
                AppColors.textPrimary,
                t,
              )!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 1 + (Motion.iconActiveScale - 1) * t,
                    child: Icon(
                      selected ? activeIcon : icon,
                      color: color,
                      size: 19,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: AppTypography.font(
                      color: color,
                      fontSize: 10,
                      fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// An indicator (pill/underline) that ANIMATES its position between equal-width
/// tabs over [Motion.base] — never an instant jump (Kalshi category-bar feel).
/// Place it spanning the full width of a [count]-tab row; it slides to [index].
class SlidingTabIndicator extends StatelessWidget {
  final int count;
  final int index;
  final double height;
  final Color color;

  /// Horizontal inset applied inside each tab slot (controls the pill width).
  final EdgeInsets slotPadding;
  final BorderRadius? radius;

  const SlidingTabIndicator({
    super.key,
    required this.count,
    required this.index,
    required this.color,
    this.height = 3,
    this.slotPadding = EdgeInsets.zero,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    // Map index → alignment.x in [-1, 1] for an equal-width slot layout.
    final x = count <= 1 ? 0.0 : (index / (count - 1)) * 2 - 1;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: AnimatedAlign(
        duration: Motion.reduced(context) ? Duration.zero : Motion.base,
        curve: Motion.standard,
        alignment: Alignment(x, 0),
        child: FractionallySizedBox(
          widthFactor: 1 / count,
          child: Padding(
            padding: slotPadding,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: radius ?? BorderRadius.circular(height),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A lightweight pulsing placeholder block for loading states — shows instead of
/// a blank screen or an error flash until the first data load resolves.
/// A shimmering placeholder list — the standard loading state for card lists
/// (replaces bare spinners). Safe to drop into any layout (shrink-wraps).
class SkeletonList extends StatelessWidget {
  final int count;
  final double height;
  final EdgeInsets padding;
  const SkeletonList({
    super.key,
    this.count = 5,
    this.height = 92,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Skeleton(
          height: height,
          radius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }
}

class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? radius;
  final EdgeInsets margin;

  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final block = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: widget.radius ?? BorderRadius.circular(8),
      ),
    );
    return Padding(
      padding: widget.margin,
      child: TickerMode(
        enabled: !reduced,
        child: reduced
            ? block
            : FadeTransition(
                opacity: Tween<double>(
                  begin: 0.45,
                  end: 0.9,
                ).animate(CurvedAnimation(parent: _c, curve: Motion.standard)),
                child: block,
              ),
      ),
    );
  }
}

/// A number / price that rolls each DIGIT vertically when it changes, like a
/// mechanical odometer (Part 3.6) — the app's most "instrument-like" micro-
/// interaction (numbers that roll read as instruments; numbers that blink read
/// as spreadsheets). Only changed digits move; static glyphs (`$ , .`) stay put.
/// Collapses to a plain value under reduced motion.
///
/// ```dart
/// RollingNumber('\$45', style: AppTypography.num(20))
/// ```
class RollingNumber extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final Duration duration;

  const RollingNumber(
    this.value, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < value.length; i++)
          _RollingGlyph(
            char: value[i],
            slot: i,
            style: style,
            duration: duration,
            reduced: reduced,
          ),
      ],
    );
  }
}

class _RollingGlyph extends StatelessWidget {
  final String char;
  final int slot;
  final TextStyle? style;
  final Duration duration;
  final bool reduced;

  const _RollingGlyph({
    required this.char,
    required this.slot,
    required this.style,
    required this.duration,
    required this.reduced,
  });

  bool get _isDigit {
    final c = char.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39; // '0'..'9'
  }

  @override
  Widget build(BuildContext context) {
    if (reduced || !_isDigit) return Text(char, style: style);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, anim) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
        // Key by slot+value: identical digits in different places stay distinct,
        // and a value change at one slot rolls only that digit.
        child: Text(char, key: ValueKey<String>('$slot:$char'), style: style),
      ),
    );
  }
}
