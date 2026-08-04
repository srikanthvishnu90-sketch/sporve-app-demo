import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/sport_colors.dart';
import 'sporve_image.dart';

/// Product-layer scaffold — solid black canvas. Use on every in-app screen.
///
/// (Named `GradientScaffold` for backward compatibility with the ~22 screens
/// that already use it; it no longer paints the old navy gradient.)
class GradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomSheet;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomSheet,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent so the app-wide solid canvas (app.dart builder) shows
      // through — every product screen shares the same near-black canvas.
      backgroundColor: Colors.transparent,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomSheet: bottomSheet,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: body,
    );
  }
}

/// Clearer alias for new code. Identical to [GradientScaffold] (black canvas).
class AppScaffold extends GradientScaffold {
  const AppScaffold({
    super.key,
    required super.body,
    super.appBar,
    super.bottomNavigationBar,
    super.floatingActionButton,
    super.floatingActionButtonLocation,
    super.bottomSheet,
    super.resizeToAvoidBottomInset,
    super.extendBody,
    super.extendBodyBehindAppBar,
  });
}

/// Entry-layer scaffold — the slate wall. Use ONLY on splash + auth/get-started.
class SlateScaffold extends StatelessWidget {
  final Widget body;
  final bool resizeToAvoidBottomInset;
  const SlateScaffold({
    super.key,
    required this.body,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.slateWall),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: body,
      ),
    );
  }
}

/// Dark search field — `surface` fill, hairline border, slate focus ring.
/// Replaces the old light `#F1F5F9` box (a light box on black reads childish).
class CustomSearchField extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  const CustomSearchField({
    super.key,
    this.hint = 'Ask Sporve to find a coach…',
    this.onTap,
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: TextField(
          controller: controller,
          enabled: onTap == null,
          readOnly: onTap != null,
          onTap: onTap,
          onChanged: onChanged,
          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14),
          cursorColor: AppColors.slateText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            // AI-native: the search bar IS the Sporve AI prompt.
            prefixIcon: const Icon(
              Icons.auto_awesome,
              color: AppColors.slateText,
              size: 20,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(
                color: AppColors.slateBorder,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Category selector rendered as a text + slate-underline tab (Kalshi style),
/// not a filled bubble. Active = white label + 2px slate underline.
class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.slateText : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.font(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// A 1px hairline divider.
class Hairline extends StatelessWidget {
  final double indent;
  final double endIndent;
  const Hairline({super.key, this.indent = 0, this.endIndent = 0});
  @override
  Widget build(BuildContext context) => Divider(
    height: 0.5,
    thickness: 0.5,
    indent: indent,
    endIndent: endIndent,
    color: AppColors.hairline,
  );
}

/// Slate outline pill — the Kalshi leverage-pill pattern (NEW, LIVE, U12, VIEW…).
/// Use liberally for status/level. This is a primary way slate recurs.
class OutlinePill extends StatelessWidget {
  final String label;
  final Color color;
  const OutlinePill(this.label, {super.key, this.color = AppColors.slateText});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.chip),
      border: Border.all(
        color: color == AppColors.slateText ? AppColors.slateBorder : color,
      ),
    ),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.font(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    ),
  );
}

/// Sport tag — tint background + sport-color text. The canonical metadata chip.
class SportTag extends StatelessWidget {
  final String sport;
  const SportTag(this.sport, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = SportColors.of(sport);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        // Bolder, more defined sport chip (Kalshi-style category cue): stronger
        // tint + a hairline in the sport color.
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: c.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            sport,
            style: AppTypography.font(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI badge — the only blue-bordered pill. Marks AI features / suggestions.
class AIBadge extends StatelessWidget {
  final String label;
  const AIBadge({super.key, this.label = 'AI'});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.blueTint,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      border: Border.all(color: AppColors.blue.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, color: AppColors.blueText, size: 11),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: AppTypography.font(
            color: AppColors.blueText,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );
}

/// Sport icon tile — tint base + sport-color glyph. Replaces colored "bubbles".
class SportIconTile extends StatelessWidget {
  final String sport;
  final double size;
  const SportIconTile(this.sport, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final c = SportColors.of(sport);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SportColors.tileTintOf(sport),
        borderRadius: BorderRadius.circular(AppRadii.tile),
        boxShadow: SportColors.glowOf(sport, intensity: 0.8),
      ),
      child: Icon(SportColors.iconOf(sport), color: c, size: size * 0.52),
    );
  }
}

/// "See all ›" — slate label + slate chevron, for every section header.
class SeeAll extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  const SeeAll({super.key, this.onTap, this.label = 'See all'});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.slateText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.slateText, size: 16),
      ],
    ),
  );
}

/// A solid slate circle with a dark forward icon — the confident affordance on
/// featured banners ("Find a session near you").
class SlateCircleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final double size;
  const SlateCircleButton({
    super.key,
    this.onTap,
    this.icon = Icons.arrow_forward,
    this.size = 38,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.slate,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, color: AppColors.onSlate, size: size * 0.45),
      ),
    ),
  );
}

/// Featured / horizontal program card. Tight 10px radius, hairline border,
/// one sport color (3px accent bar + tag), mono price, gold rating star.
class NearYouCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String rating;
  final String image;
  final String? sport;
  final VoidCallback? onTap;

  const NearYouCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.rating,
    required this.image,
    this.sport,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sportColor = SportColors.of(sport);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SporveImage(
                  image,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: sportColor),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(13.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [SportColors.washOf(sport), Colors.transparent],
                  stops: const [0.0, 0.7],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sport != null) ...[
                    SportTag(sport!),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price,
                        style: AppTypography.mono(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: AppColors.textPrimary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: AppTypography.mono(
                              size: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
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
}

/// A program list item rendered as a hairline row (not a filled card):
/// sport icon-tile · title + metadata · mono price · slate chevron.
class ProgramListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String rating;
  final String image; // kept for API compat; row uses a sport icon-tile
  final String schedule;
  final String? sport;
  final VoidCallback? onTap;

  const ProgramListItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.rating,
    required this.image,
    required this.schedule,
    this.sport,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = sport ?? subtitle;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SporveImage(
              image.isNotEmpty ? image : SportColors.fallbackImageOf(s),
              width: 52,
              height: 52,
              radius: AppRadii.tile,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 14),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.font(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      _dot(),
                      const Icon(
                        Icons.star,
                        color: AppColors.textPrimary,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: AppTypography.mono(
                          size: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      _dot(),
                      Text(
                        price,
                        style: AppTypography.mono(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 7),
    child: Icon(Icons.circle, color: AppColors.textTertiary, size: 3),
  );
}

/// Consistent icon-only button — a tight rounded-square (radius 8) on a subtle
/// surface, with a press-scale. Use for back/share/camera/edit/remove/add etc.
/// `filled:true` makes it a solid deep-slate primary affordance (white icon).
class SporveIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color; // icon color (ignored when filled)
  final bool filled; // solid slate primary
  final bool border; // hairline border (when not filled)
  final bool circle; // round instead of rounded-square

  /// Screen-reader label for this icon-only control (e.g. 'Back', 'Close').
  /// Without it a TalkBack/VoiceOver user hears only "button".
  final String? semanticLabel;
  const SporveIconButton(
    this.icon, {
    super.key,
    this.onTap,
    this.size = 38,
    this.iconSize = 18,
    this.color,
    this.filled = false,
    this.border = true,
    this.circle = false,
    this.semanticLabel,
  });

  @override
  State<SporveIconButton> createState() => _SporveIconButtonState();
}

class _SporveIconButtonState extends State<SporveIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final bg = widget.filled ? AppColors.slate : AppColors.surface;
    final fg = widget.filled
        ? AppColors.onSlate
        : (widget.color ?? AppColors.textPrimary);
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        label: widget.semanticLabel,
        child: Listener(
          onPointerDown: widget.onTap == null
              ? null
              : (_) => setState(() => _pressed = true),
          onPointerUp: widget.onTap == null
              ? null
              : (_) => setState(() => _pressed = false),
          onPointerCancel: widget.onTap == null
              ? null
              : (_) => setState(() => _pressed = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            // Keep the visual at `size` but guarantee a ≥44pt tappable area
            // (iOS 44 / WCAG target minimum) without changing the layout.
            child: SizedBox(
              width: widget.size < 44 ? 44 : widget.size,
              height: widget.size < 44 ? 44 : widget.size,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      shape:
                          widget.circle ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: widget.circle
                          ? null
                          : BorderRadius.circular(AppRadii.tile),
                      border: (widget.border && !widget.filled)
                          ? Border.all(color: AppColors.hairline)
                          : null,
                    ),
                    child: Icon(widget.icon, size: widget.iconSize, color: fg),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Consistent segmented control (e.g. MONTH/WEEK/DAY, DIRECT/PROGRAMS) — a
/// surface track with the active segment as a deep-slate pill (white label),
/// inactive labels in secondary gray. Flat, tight, Kalshi/Uber register.
class SporveSegmented extends StatelessWidget {
  final List<String> segments;
  final int selected;
  final ValueChanged<int> onChanged;
  const SporveSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: List.generate(segments.length, (i) {
          final on = i == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.slate : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.tile - 2),
                ),
                child: Text(
                  segments[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: on ? AppColors.onSlate : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Consistent empty state — icon + title + optional message. Use whenever a list
/// has genuinely no data (NOT for load failures — use [ErrorRetry] for those).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final EdgeInsetsGeometry padding;
  final String? actionLabel; // optional CTA
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.slateTint,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    border: Border.all(color: AppColors.slateBorder),
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppTypography.font(
                      color: AppColors.slateText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A load-FAILURE state with a Try-again action — so a network/server error
/// reads as "couldn't load" with a retry, never as a misleading empty list.
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;
  const ErrorRetry({
    super.key,
    this.message =
        "We couldn't load this. Check your connection and try again.",
    required this.onRetry,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 36,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.slateTint,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: AppColors.slateBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh,
                      size: 16,
                      color: AppColors.slateText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Try again',
                      style: AppTypography.font(
                        color: AppColors.slateText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slate-styled confirm dialog. Returns true if the user confirmed. Use for any
/// hard-to-reverse action (sign out, delete, cancel) before doing it.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.hairline),
      ),
      title: Text(
        title,
        style: AppTypography.font(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        message,
        style: AppTypography.font(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            cancelLabel,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: AppTypography.font(
              color: destructive ? AppColors.negative : AppColors.slateText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Unserved-area waitlist capture (§2) — converts zero-result searches in an
/// unserved region into a demand signal (email + ZIP code capture) that tells
/// platform ops where to recruit supply next.
class UnservedWaitlistCard extends StatefulWidget {
  final String? sport;
  final String? initialZip;
  final VoidCallback? onCaptured;

  const UnservedWaitlistCard({
    super.key,
    this.sport,
    this.initialZip,
    this.onCaptured,
  });

  @override
  State<UnservedWaitlistCard> createState() => _UnservedWaitlistCardState();
}

class _UnservedWaitlistCardState extends State<UnservedWaitlistCard> {
  final _emailController = TextEditingController();
  final _zipController = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialZip != null && widget.initialZip!.isNotEmpty) {
      _zipController.text = widget.initialZip!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final zip = _zipController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    try {
      final box = GetStorage();
      final List<dynamic> signals = box.read('demand_signals') ?? [];
      signals.add({
        'email': email,
        'zip': zip.isEmpty ? '60601' : zip,
        'sport': widget.sport ?? 'Any',
        'capturedAt': DateTime.now().toIso8601String(),
      });
      box.write('demand_signals', signals);
    } catch (_) {}

    setState(() => _submitted = true);
    widget.onCaptured?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.slateBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You\'re on the waitlist!',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'We\'ll email you the moment new coaches launch near you.',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: AppColors.slateText, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Want an alert when a coach arrives?',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Get notified the moment ${widget.sport ?? 'sports'} coaches launch near your area.',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _zipController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ZIP code',
                    hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slateText,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
              child: Text(
                'Get notified',
                style: AppTypography.font(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

