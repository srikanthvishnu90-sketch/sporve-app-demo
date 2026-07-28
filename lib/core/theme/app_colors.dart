import 'package:flutter/material.dart';

/// Sporve color system — Uber-style OBSIDIAN neutral stack + BRIGHT slate brand
/// + OKLCH-calibrated sport metadata.
///
/// The canvas is PURE black (#000000). Depth comes from the neutral surface
/// steps, which carry a light slate cast so the product reads warm/branded
/// rather than abstract-neutral. Slate `#475569` (brightened) is the single
/// brand accent and carries ALL chrome — nav, tabs, borders, dividers, links,
/// search, AI, secondary type. Sport colors are the only other chroma and live
/// in `sport_colors.dart`, calibrated against one anchor in OKLCH.
///
/// The old navy palette (`navyDark`/`navyCard`/`accentBlue`/`bgGradient`...) is
/// kept ONLY as backward-compatible aliases that now point at the new system.
class AppColors {
  // ── Obsidian neutral stack (the 90%) ────────────────────────────────────
  // Pure-black canvas; raised surfaces + all structure carry SLATE so the
  // product reads branded, not abstract.
  static const Color ink = Color(0xFF000000); // canvas / page background (pure)
  static const Color surface = Color(0xFF0D0F13); // surface-1 (slate cast)
  static const Color surface2 = Color(0xFF151822); // surface-2 (raised, sheets)
  static const Color surface3 = Color(0xFF1D212B); // surface-3 (modals, popovers)
  // Hairlines are BRIGHT slate — the brand accent carries the app's structure.
  static const Color hairline = Color(0x2E475569); // ~18% slate
  static const Color hairlineStrong = Color(0x40475569); // ~25% slate
  static const Color hairlineSoft = Color(0x1A475569); // ~10% slate
  // Type: white primary, bright slate-grey secondary/muted (brand warmth).
  static const Color textPrimary = Color(0xFFF7F7F7); // primary text
  static const Color textSecondary = Color(0xFFA6B3BF); // secondary (slate-grey)
  static const Color textTertiary = Color(0xFF78848F); // muted (slate-muted)
  static const Color inkOnSlate = Color(0xFF0A0A0A); // dark text on light fills

  // ── Brand ───────────────────────────────────────────────────────────────
  // The single brand accent is BRIGHT SLATE (#475569) — brightened once more
  // from #647B8F for stronger presence across all chrome.
  static const Color slate = Color(0xFF475569); // PRIMARY accent (bright slate)
  static const Color slateDeep = Color(0xFF3A4656); // pressed
  static const Color slateText = Color(0xFF475569); // slate accent for text/icons
  static const Color slateTint = Color(0x3D475569); // ~24% slate fill
  static const Color slateBorder = Color(0x80475569); // ~50% slate border
  static const Color slateBrand = Color(0xFF475569); // splash is flat slate
  static const Color onSlate = Color(0xFFFFFFFF); // text/icons ON a slate fill
  // AI / social were a distinct blue; folded into slate (single accent).
  static const Color blue = Color(0xFF475569);
  static const Color blueText = Color(0xFF475569);
  static const Color blueTint = Color(0x3D475569);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color positive = slateText; // up / confirmed (slate)
  // Non-destructive "negative" (down/error states) is MUTED slate — never red.
  static const Color negative = Color(0xFF78848F);
  static const Color negativeTint = Color(0x2478848F); // ~14% muted fill
  static const Color warning = Color(0xFF475569);
  static const Color warningTint = Color(0x2E475569);
  // RED IS DESTRUCTIVE ONLY (Sign out, Delete) — reserved, exclusive meaning.
  static const Color destructiveRed = Color(0xFFEF4444);
  // TRUST GOLD is reserved EXCLUSIVELY for vetting / trust badges.
  static const Color trustGold = Color(0xFFD4A94E);

  // ── Semantic status accents (folded onto the anchor) ────────────────────
  static const Color successGreen = Color(0xFF13A240); // anchor L/C, green
  static const Color successTint = Color(0x2413A240);
  static const Color warmAccent = Color(0xFFB87800); // anchor L/C, amber
  static const Color warmTint = Color(0x24B87800);

  /// Off-canvas letterbox behind the phone frame on desktop web — pure black.
  static const Color frame = Color(0xFF000000);

  // ── Entry-wall gradient (Layer 1 only: splash + auth) ───────────────────
  static const LinearGradient slateWall = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF475569), Color(0xFF475569), Color(0xFF475569)],
    stops: [0.0, 0.55, 1.0],
  );

  // ── Brand gradient (logo + rare brand moments only) ─────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF475569), Color(0xFF3A4656)],
  );

  // ── Backward-compatible aliases (legacy names → new system) ─────────────
  static const Color navyDark = ink; // → pure-black canvas
  static const Color navyCard = surface; // → surface-1
  static const Color accentBlue = slate; // → bright brand slate
  static const Color textGrey = textSecondary; // subtitles / hints
  static const Color inputFill = surface; // → surface-1

  /// Legacy "background gradient" — now a flat pure-black canvas.
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ink, ink],
  );

  // ── AI concierge chat surface + auth entry wall ─────────────────────────
  // Additive tokens for the AI concierge screen (now reached from Profile) and
  // the auth entry wall. These do NOT alter any original palette value.
  static const Color entryWall = Color(0xFF475569);
  static const Color chatCanvas = Color(0xFF06090D); // deep blue-black base
  static const Color chatSurface = Color(0xFF0B1018); // pill / bubble surface
  static const Color chatAccent = Color(0xFF6082A8); // send / active slate-blue
  static const Color chatTextBright = Color(0xFFEEF3F8); // greeting / bubbles
  static const Color chatInputText = Color(0xFFE8EEF5); // input field text
  static const Color chatTextMuted = Color(0xFFAEB7C4); // labels / mic
  static const Color chatIcon = Color(0xFF8B94A3); // top-bar icons
  static const Color chatIconBright = Color(0xFFDDE3EB); // plus icon
  static const Color chatLogoText = Color(0xFFBFD4E8); // S mark / typing dots
  static const Color chatPlaceholder = Color(0xFF7B8494); // hint / meta
  static const Color chatDisclaimer = Color(0xFF5F6877); // Caption disclaimer
  static const Color chatError = Color(0xFFE8899A); // error bubble text
}
