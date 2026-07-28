import 'package:flutter/material.dart';

/// A subtle, STATIC "ambient" background treatment layered OVER an existing
/// background color/gradient. It never replaces or shifts the base color — it
/// only lifts luminance a few percent with a soft radial glow.
///
/// Composited bottom → top:
///   1. Base color/gradient (passed in verbatim — never hardcoded, never altered)
///   2. Radial luminance glow (white overlay, transparent by ~75% radius)
///   2b. Optional faint counter-glow so edges don't feel dead
///
/// Everything here is STILL — zero animation — so the whole background is
/// wrapped in a [RepaintBoundary] and paints exactly once per screen.
/// The foreground [child] renders ABOVE the treatment untouched: no opacity or
/// blend inheritance reaches cards, buttons, text, or inputs.
class AmbientSurface extends StatelessWidget {
  final Widget child;

  /// LAYER 1 — the screen's existing background. Supply a solid [baseColor] OR
  /// a [baseGradient] (e.g. `AppColors.slateWall`). One is required.
  final Color? baseColor;
  final Gradient? baseGradient;

  /// LAYER 2 — radial luminance glow.
  final Alignment focal;
  final double radius;

  /// Peak white opacity at [focal]; this is the maximum luminance lift on screen
  /// (keep ≤ 0.08 so it reads as "lit," not "recolored").
  final double glowOpacity;

  /// LAYER 2b — a second, even softer glow at [counterFocal] to keep the far
  /// edge from feeling dead. Kept ≤ 0.02.
  final bool counterGlow;
  final Alignment counterFocal;
  final double counterGlowOpacity;

  const AmbientSurface({
    super.key,
    required this.child,
    this.baseColor,
    this.baseGradient,
    this.focal = Alignment.center,
    this.radius = 1.1,
    this.glowOpacity = 0.06,
    this.counterGlow = true,
    this.counterFocal = const Alignment(0.9, 0.95),
    this.counterGlowOpacity = 0.02,
  }) : assert(
         baseColor != null || baseGradient != null,
         'AmbientSurface requires a baseColor or a baseGradient',
       );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The treatment is fully static, so paint it once and never again.
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // LAYER 1 — base, exactly as passed in.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: baseColor,
                  gradient: baseGradient,
                ),
              ),
              // LAYER 2 — radial luminance glow: white at centre, gone by ~75%.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: focal,
                    radius: radius,
                    colors: [
                      Colors.white.withValues(alpha: glowOpacity),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.75],
                  ),
                ),
              ),
              // LAYER 2b — optional counter-glow.
              if (counterGlow)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: counterFocal,
                      radius: radius,
                      colors: [
                        Colors.white.withValues(alpha: counterGlowOpacity),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Foreground — untouched by the treatment above.
        child,
      ],
    );
  }
}
