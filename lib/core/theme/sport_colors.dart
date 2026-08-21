import 'dart:ui' show ColorSpace;
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Sport-identity layer (Layer 3) — the per-sport color answers "what sport?"
/// at a glance and does nothing else. It is the ONLY chromatic color in the
/// app (everything else is black / white / slate). Used accent-only: sport tag,
/// icon-tile glyph, the in-context action button, a sport status pill, and
/// calendar session dots — never on chrome, never a card background.
/// Always paired with the sport icon and/or label. Unmapped sport → slate.
///
/// COLOR SCIENCE (OKLCH). Every base below is calibrated against ONE anchor —
/// basketball/court orange, Persimmon+ #DA5A05 → OKLCH L=0.6235 C=0.1778
/// H=44.6°. Every other sport keeps the anchor's L and C and rotates ONLY its
/// hue to that sport's family, then: gamut-clips chroma (never raises L) for
/// hues that can't exist in sRGB at anchor C; drops yellows' L ~0.025 (they read
/// louder at equal OKLCH); allows blue +0.02 C (reads dim); and shifts any hue
/// that lands too near destructive-red #EF4444 or trust-gold #D4A94E by ±14°.
/// All glyphs pass ≥3:1 vs both #000000 and #0D0D0D. See the /debug/palette
/// screen and the recalibration report for per-sport OKLCH, hex, and deviations.
class SportColors {
  // Authoritative sport → calibrated base color map (single source of truth).
  // Hues globally spaced so no two sports match (min ~9° apart at anchor L/C);
  // all cleared of the destructive-red and trust-gold exclusion zones. H = final
  // OKLCH hue.
  static const Map<String, Color> _core = {
    'basketball': Color(0xFFDA5A05), // ANCHOR            H=44.6
    'climbing': Color(0xFFCE6600), // burnt orange        H=53.2  clip
    'football': Color(0xFFC27000), // American football   H=62.5  clip
    'football (am.)': Color(0xFFC27000),
    'softball': Color(0xFFB77800), // amber (below gold)  H=72.7  clip
    'tennis': Color(0xFF878500), // yellow→olive          H=109   liar,clip
    'cycling': Color(0xFF748C00), // yellow-green→olive    H=121   liar,clip
    'soccer': Color(0xFF2EA136), // green                 H=144
    'football (soccer)': Color(0xFF2EA136),
    'golf': Color(0xFF00A15E), // green                   H=156   clip
    'lacrosse': Color(0xFF009F77), // green-teal           H=167   clip
    'cricket': Color(0xFF009D87), // teal-green            H=178   clip
    'swimming': Color(0xFF009AA0), // cyan                 H=200   clip
    'diving': Color(0xFF009AA0),
    'ski / snowboard': Color(0xFF0098AD), // teal          H=212   clip
    'skiing': Color(0xFF0098AD),
    'snowboarding': Color(0xFF0098AD),
    'figure skating': Color(0xFF0098AD),
    'skating': Color(0xFF0098AD),
    'water polo': Color(0xFF0096BA), // teal-blue          H=223   clip
    'surfing': Color(0xFF0096BA),
    'ice hockey': Color(0xFF0092CA), // blue               H=234   blue,clip
    'hockey': Color(0xFF0092CA),
    'badminton': Color(0xFF008DE0), // blue                H=245   blue,clip
    'baseball': Color(0xFF2384FB), // blue                 H=257   blue
    'rowing': Color(0xFF537BFD), // indigo-blue            H=268   blue
    'rowing / crew': Color(0xFF537BFD),
    'crew': Color(0xFF537BFD),
    'sailing': Color(0xFF537BFD),
    'martial arts': Color(0xFF7172FA), // blue-violet      H=279   blue
    'mma': Color(0xFF7172FA),
    'karate': Color(0xFF7172FA),
    'judo': Color(0xFF7172FA),
    'taekwondo': Color(0xFF7172FA),
    'fencing': Color(0xFF886AF4), // violet                H=290   blue
    'track & field': Color(0xFF9A68E0), // violet          H=301
    'track and field': Color(0xFF9A68E0),
    'track': Color(0xFF9A68E0),
    'running': Color(0xFF9A68E0),
    'cross country': Color(0xFF9A68E0),
    'triathlon': Color(0xFF9A68E0),
    'gymnastics': Color(0xFFAB61D3), // purple             H=312
    'cheer': Color(0xFFC456B3), // magenta                 H=334
    'cheerleading': Color(0xFFC456B3),
    'dance': Color(0xFFCE529E), // pink-magenta            H=346
    'volleyball': Color(0xFFD54F8A), // rose               H=356
    'boxing': Color(0xFFDA4E77), // rose-crimson           H=5.8
    'wrestling': Color(0xFFDD4E65), // red-crimson          H=14.3
    // racket family → tennis hue
    'pickleball': Color(0xFF878500),
    'squash': Color(0xFF878500),
    'table tennis': Color(0xFF878500),
  };

  static const Color fallback = AppColors.slate; // unmapped sport → brand slate

  /// De-duplicated, title-cased display names for sport pickers — every entry
  /// maps to a real color via [of]. Use this everywhere a sport is chosen so the
  /// full catalogue (not a hardcoded handful) is always offered.
  static const List<String> pickerNames = [
    'Basketball',
    'Soccer',
    'Football',
    'Baseball',
    'Softball',
    'Tennis',
    'Pickleball',
    'Volleyball',
    'Swimming',
    'Diving',
    'Water Polo',
    'Track & Field',
    'Cross Country',
    'Gymnastics',
    'Wrestling',
    'Boxing',
    'Martial Arts',
    'MMA',
    'Karate',
    'Judo',
    'Taekwondo',
    'Fencing',
    'Ice Hockey',
    'Figure Skating',
    'Skiing',
    'Snowboarding',
    'Golf',
    'Lacrosse',
    'Cricket',
    'Cheerleading',
    'Dance',
    'Cycling',
    'Climbing',
    'Rowing',
    'Badminton',
    'Squash',
    'Surfing',
  ];

  static String _key(String? sport) => (sport ?? '').toLowerCase().trim();

  // ── The three intensities (the entire vocabulary) ───────────────────────
  // Every sport-colored surface is built from exactly these, derived
  // mechanically from the calibrated base. No other opacities, no exceptions.

  /// GLYPH — the calibrated base, BRIGHTENED to the vivid "lit" register of the
  /// reference designs. Every sport hue is lifted ~+0.10 lightness (HSL) while
  /// keeping its calibrated hue + saturation, so orange/green/yellow/etc. read
  /// bright, not muted. Contrast vs the black canvas only improves.
  static Color of(String? sport) {
    final base = _core[_key(sport)];
    if (base == null) return fallback;
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor();
  }

  /// GLYPH — semantic alias for [of] (base at 100%).
  static Color glyphOf(String? sport) => of(sport);

  /// BORDER — base at 45% opacity (outlines, hairlines around a sport well).
  static Color borderOf(String? sport) => of(sport).withValues(alpha: 0.45);

  /// WELL — base at 8% opacity (the tinted background of a tile / tag / chip).
  static Color wellOf(String? sport) => of(sport).withValues(alpha: 0.08);

  /// BLOOM — the ONE shared optional glow: a single soft halo, base at 38%,
  /// blur 12. Permitted ONLY on featured / hero surfaces, never on dense list
  /// rows. Drop into a BoxDecoration's boxShadow.
  static List<BoxShadow> bloomOf(String? sport) => [
    BoxShadow(color: of(sport).withValues(alpha: 0.38), blurRadius: 12),
  ];

  /// Legible text/glyph color to place ON a sport-color fill — a dark shade for
  /// light sports, near-white for the few dark ones.
  static Color onColorOf(String? sport) => of(sport).computeLuminance() < 0.45
      ? const Color(0xFFF7F7F7)
      : const Color(0xFF0A0A0A);

  // ── AMBIENT (Layer-3 hero variant) — FULL-BLEED MOMENTS ONLY ────────────
  // The "lit" variant that makes the sport hue feel illuminated rather than
  // painted. Used ONLY by AmbientField on splash / booking-confirmation /
  // goal-confirmed heroes — NEVER on chrome, lists, cards, or nav (enforced in
  // review + by the naming barrier: only *ambient* surfaces may call these).
  //
  // Mechanically brighter than the calibrated base: an OKLCH-style lift
  // approximated in HSL by raising lightness ~+0.10 and pushing chroma to the
  // gamut ceiling (saturation → max). Persimmon anchor #DA5A05 → ~#F2680A
  // (vivid, luminous orange — the Step-1 target territory).

  /// AMBIENT (sRGB) — the guaranteed-everywhere lit variant.
  static Color ambientOf(String? sport) {
    final hsl = HSLColor.fromColor(of(sport));
    return hsl
        .withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0))
        .withSaturation(1.0)
        .toColor();
  }

  /// AMBIENT (Display P3) — Step 2 wide-gamut unlock. Reinterprets the ambient
  /// components in the Display P3 space so chroma exceeds the sRGB ceiling on
  /// Impeller/iOS wide-gamut displays; Flutter auto-maps back to sRGB on other
  /// platforms, so [ambientOf] is the automatic fallback. ONLY ambient variants
  /// go wide — structural colors stay sRGB. Documented anchor components
  /// (Persimmon-ambient, normalized): r≈0.949 g≈0.408 b≈0.039, space=displayP3.
  static Color ambientP3Of(String? sport) {
    final c = ambientOf(sport);
    return Color.from(
      alpha: 1.0,
      red: c.r,
      green: c.g,
      blue: c.b,
      colorSpace: ColorSpace.displayP3,
    );
  }

  /// Neutral content color for an ambient field — white or ink ONLY (no second
  /// hue may ever enter an ambient field). Picks whichever meets WCAG 4.5:1 on
  /// the LIGHT ambient variant; the dark variant always uses white.
  static Color onAmbientOf(String? sport) =>
      ambientOf(sport).computeLuminance() > 0.24
      ? const Color(0xFF0A0A0A) // ink
      : const Color(0xFFFFFFFF); // white

  // ── Legacy accessors → repointed onto the three intensities ─────────────
  // Kept so existing call sites compile; each now resolves to a canonical
  // intensity. Prefer glyphOf / borderOf / wellOf / bloomOf in new code.

  /// Legacy tag tint → WELL (8%).
  static Color tintOf(String? sport) => wellOf(sport);

  /// Legacy icon-tile base → WELL (8%).
  static Color tileTintOf(String? sport) => wellOf(sport);

  /// Legacy header wash → WELL (8%).
  static Color washOf(String? sport) => wellOf(sport);

  /// Legacy neon glow → BLOOM. `intensity` is accepted for call-site
  /// compatibility but the bloom token is fixed (single 12px halo at 38%).
  static List<BoxShadow> glowOf(String? sport, {double intensity = 1.0}) =>
      bloomOf(sport);

  /// Functional image scrim for cover-image gradient legibility (NOT a
  /// sport-identity swatch — documented exception to the 3-intensity rule).
  static Color scrimOf(String? sport) => of(sport).withValues(alpha: 0.60);

  /// Sport → line/duotone icon. Replaces every emoji in the product.
  static IconData iconOf(String? sport) {
    switch (_key(sport)) {
      case 'basketball':
        return Icons.sports_basketball;
      case 'soccer':
      case 'football (soccer)':
        return Icons.sports_soccer;
      case 'tennis':
      case 'pickleball':
      case 'badminton':
      case 'table tennis':
      case 'squash':
        return Icons.sports_tennis;
      case 'golf':
        return Icons.sports_golf;
      case 'baseball':
      case 'softball':
        return Icons.sports_baseball;
      case 'swimming':
      case 'diving':
      case 'water polo':
        return Icons.pool;
      case 'football':
        return Icons.sports_football;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'hockey':
      case 'ice hockey':
        return Icons.sports_hockey;
      case 'wrestling':
      case 'boxing':
      case 'mma':
      case 'karate':
      case 'judo':
        return Icons.sports_mma;
      case 'track':
      case 'track & field':
      case 'running':
      case 'cross country':
      case 'triathlon':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'skiing':
      case 'snowboarding':
        return Icons.downhill_skiing;
      case 'gymnastics':
      case 'cheer':
      case 'cheerleading':
      case 'dance':
        return Icons.sports_gymnastics;
      default:
        return Icons.sports;
    }
  }

  /// Maps a legacy sport emoji (still present in data/widgets) to a line icon,
  /// so any code passing an emoji string renders a refined glyph instead.
  static IconData iconForEmoji(String? emoji) {
    switch ((emoji ?? '').trim()) {
      case '🏀':
        return Icons.sports_basketball;
      case '⚽':
        return Icons.sports_soccer;
      case '🏈':
        return Icons.sports_football;
      case '🎾':
        return Icons.sports_tennis;
      case '⚾':
      case '🥎':
        return Icons.sports_baseball;
      case '🏐':
        return Icons.sports_volleyball;
      case '🏊':
      case '🏊‍♂️':
        return Icons.pool;
      case '⛳':
      case '🏌️':
        return Icons.sports_golf;
      case '🏒':
        return Icons.sports_hockey;
      case '🥍':
        return Icons.sports_hockey;
      case '🤼':
      case '🥊':
        return Icons.sports_mma;
      case '🏃':
      case '🏃‍♂️':
        return Icons.directions_run;
      case '🚴':
        return Icons.directions_bike;
      case '⛷️':
      case '🏂':
        return Icons.downhill_skiing;
      case '🤸':
        return Icons.sports_gymnastics;
      default:
        // Maybe a sport *name* was passed rather than an emoji.
        return iconOf(emoji);
    }
  }

  /// No remote stock-photo fallback. Missing provider imagery stays honest and
  /// lets [SporveImage] render its designed local placeholder. This keeps the
  /// demo offline-capable and avoids unversioned third-party hotlinks.
  static String fallbackImageOf(String? sport) => '';
}
