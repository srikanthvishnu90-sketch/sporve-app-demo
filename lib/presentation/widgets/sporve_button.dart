import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/ui/motion.dart';

/// Visual role of a button. Color encodes importance consistently app-wide.
enum SporveButtonVariant {
  /// Main action — solid deep-slate (or sport color), white text. One per screen.
  primary,

  /// Secondary on the dark canvas — transparent + hairline border.
  dark,

  /// White pill with dark text — entry-wall social/login buttons.
  white,

  /// Near-black pill with white text — the entry-wall PRIMARY CTA. On the
  /// lifted slate wall a white pill washes out, so the main action goes dark
  /// for maximum contrast (Kalshi-style: bright wall, near-black button).
  entryDark,

  /// Lower-emphasis filled — subtle surface fill.
  secondary,

  /// Lowest-emphasis — text only.
  tertiary,

  /// Destructive — ghost (muted-red text, no fill).
  destructive,
}

enum SporveButtonSize { large, compact }

/// The single button used across Sporve — Uber/Kalshi register: tall, tight
/// radius (8), restrained 15px/600 label, flat (no shadow), with a subtle
/// press-scale for a premium tactile feel. Route EVERY CTA through this so the
/// whole app's buttons look and feel identical.
class SporveButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final SporveButtonVariant variant;
  final SporveButtonSize size;
  final IconData? icon;

  /// Custom leading widget (e.g. a brand SVG logo). Takes priority over [icon].
  final Widget? leadingWidget;

  final bool loading;
  final bool fullWidth;

  /// For [secondary]/[tertiary] on dark backgrounds — picks light text/border.
  final bool onDark;

  /// Accent override for the [primary] variant (text auto-contrasts). For a
  /// SPORT-CONTEXT CTA (book / confirm / continue on a specific sport's listing)
  /// pass that sport's color so the action carries the sport identity
  /// (basketball orange, etc.) — this is how we diversify off an all-slate look.
  /// Leave null for generic chrome (auth, generic actions) so primary defaults
  /// to the slate brand accent.
  final Color? color;

  const SporveButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.variant = SporveButtonVariant.primary,
    this.size = SporveButtonSize.large,
    this.icon,
    this.leadingWidget,
    this.loading = false,
    this.fullWidth = true,
    this.onDark = false,
    this.color,
  });

  @override
  State<SporveButton> createState() => _SporveButtonState();
}

class _SporveButtonState extends State<SporveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isLarge = widget.size == SporveButtonSize.large;
    final double height = isLarge ? 52 : 44;
    final double fontSize = isLarge ? 15 : 14;
    final EdgeInsets pad = EdgeInsets.symmetric(horizontal: isLarge ? 20 : 16);
    final bool disabled = widget.onPressed == null || widget.loading;

    // Tight tile radius everywhere except the entry-wall pills (999).
    final double radius =
        (widget.variant == SporveButtonVariant.white ||
            widget.variant == SporveButtonVariant.entryDark)
        ? AppRadii.pill
        : AppRadii.tile;

    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;
    switch (widget.variant) {
      case SporveButtonVariant.primary:
        bg = widget.color ?? AppColors.slate;
        // Select a WCAG-safe foreground for custom sport colors.
        fg = bg.computeLuminance() < 0.18
            ? AppColors.textPrimary
            : AppColors.inkOnSlate;
        break;
      case SporveButtonVariant.dark:
        bg = Colors.transparent;
        fg = AppColors.textPrimary;
        side = const BorderSide(color: AppColors.hairline, width: 1);
        break;
      case SporveButtonVariant.white:
        bg = Colors.white;
        fg = AppColors.inkOnSlate;
        break;
      case SporveButtonVariant.entryDark:
        bg = AppColors.ink; // pure black — pops on the lifted slate wall
        fg = AppColors.onSlate;
        break;
      case SporveButtonVariant.destructive:
        // Destructive (Sign out / Delete / Remove) is the ONLY red in the app.
        bg = Colors.transparent;
        fg = AppColors.destructiveRed;
        break;
      case SporveButtonVariant.secondary:
        bg = widget.onDark
            ? AppColors.surface2
            : AppColors.inkOnSlate.withValues(alpha: 0.16);
        fg = widget.onDark ? AppColors.textPrimary : AppColors.inkOnSlate;
        break;
      case SporveButtonVariant.tertiary:
        bg = Colors.transparent;
        fg = widget.onDark ? AppColors.slateText : AppColors.inkOnSlate;
        break;
    }

    final textStyle = AppTypography.font(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: fg,
    );

    final Widget child = widget.loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: widget.fullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.leadingWidget != null) ...[
                widget.leadingWidget!,
                const SizedBox(width: 10),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? bg.withValues(alpha: 0.45)
            : bg,
      ),
      foregroundColor: WidgetStateProperty.all(fg),
      overlayColor: WidgetStateProperty.all(fg.withValues(alpha: 0.10)),
      side: side == BorderSide.none
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? side.copyWith(color: side.color.withValues(alpha: 0.4))
                  : side,
            ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      elevation: WidgetStateProperty.all(0),
      padding: WidgetStateProperty.all(pad),
      minimumSize: WidgetStateProperty.all(
        Size(widget.fullWidth ? double.infinity : 0, height),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    final button = TextButton(
      onPressed: disabled
          ? null
          : () {
              // Uniform selection haptic on every CTA tap (matches PressableScale).
              HapticFeedback.selectionClick();
              widget.onPressed!();
            },
      style: style,
      child: child,
    );

    // Subtle press-scale (shared motion system) layered over the Material ripple.
    return Listener(
      onPointerDown: disabled ? null : (_) => setState(() => _pressed = true),
      onPointerUp: disabled ? null : (_) => setState(() => _pressed = false),
      onPointerCancel: disabled
          ? null
          : (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? Motion.pressScale : 1.0,
        duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
        curve: Motion.standard,
        child: SizedBox(
          width: widget.fullWidth ? double.infinity : null,
          height: height,
          child: button,
        ),
      ),
    );
  }
}
