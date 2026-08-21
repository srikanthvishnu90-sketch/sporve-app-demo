import 'package:flutter/material.dart';

/// Sporve color system — obsidian canvas, Persimmon action anchor, distinct
/// semantic feedback, and accessible lifted foregrounds.
///
/// Stable legacy token names remain so components do not fork their styling.
/// `slate` is now the locked Persimmon action fill; structural slate stays in
/// borders and [slateFg]. Sport-specific colors remain in `sport_colors.dart`.
class AppColors {
  // Obsidian surfaces.
  static const Color ink = Color(0xFF000000);
  static const Color surface = Color(0xFF0D0F13);
  static const Color surface2 = Color(0xFF151822);
  static const Color surface3 = Color(0xFF1D212B);
  static const Color hairline = Color(0x2E475569);
  static const Color hairlineStrong = Color(0x40475569);
  static const Color hairlineSoft = Color(0x1A475569);

  // Text.
  static const Color textPrimary = Color(0xFFF7F7F7);
  static const Color textSecondary = Color(0xFFA6B3BF);
  static const Color textTertiary = Color(0xFF8A96A3);
  static const Color inkOnSlate = Color(0xFF0A0A0A);

  // Action and structural foregrounds.
  static const Color slate = Color(0xFFDA5A05); // Persimmon action anchor
  static const Color slateDeep = Color(0xFFB84804);
  // #A9B7C6 on #000000 = 10.2:1; replaces #475569 as text/icon foreground.
  static const Color slateFg = Color(0xFFA9B7C6);
  static const Color slateText = slateFg;
  static const Color slateTint = Color(0x33DA5A05);
  static const Color slateBorder = Color(0x80DA5A05);
  static const Color slateBrand = slate;
  static const Color onSlate = Color(0xFF0A0A0A);

  // Links and AI affordances are lifted slate-blue, not the action anchor.
  static const Color blue = Color(0xFF7198C0);
  static const Color blueText = Color(0xFF9ABDE0);
  static const Color blueTint = Color(0x337198C0);
  static const Color aiAccent = blue;

  // Semantic feedback: intentionally distinct in hue and icon-compatible.
  static const Color positive = Color(0xFF67B18A);
  static const Color positiveTint = Color(0x3367B18A);
  static const Color negative = Color(0xFFD87878);
  static const Color negativeTint = Color(0x33D87878);
  static const Color warning = Color(0xFFD0A24C);
  static const Color warningTint = Color(0x33D0A24C);
  static const Color destructiveRed = Color(0xFFEF4444);
  static const Color trustGold = Color(0xFFD4A94E);

  // Backward-compatible status aliases.
  static const Color successGreen = positive;
  static const Color successTint = positiveTint;
  static const Color warmAccent = warning;
  static const Color warmTint = warningTint;

  static const Color frame = ink;

  // Entry and brand gradients are genuinely multi-stop.
  static const LinearGradient slateWall = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6E2E08), Color(0xFF35190B), surface],
    stops: [0.0, 0.55, 1.0],
  );
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [slate, slateDeep],
  );

  // Legacy aliases.
  static const Color navyDark = ink;
  static const Color navyCard = surface;
  static const Color accentBlue = slate;
  static const Color textGrey = textSecondary;
  static const Color inputFill = surface;
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ink, surface],
  );

  // AI concierge/chat surface.
  static const Color entryWall = Color(0xFF35190B);
  static const Color chatCanvas = Color(0xFF06090D);
  static const Color chatSurface = Color(0xFF0B1018);
  static const Color chatAccent = aiAccent;
  static const Color chatTextBright = Color(0xFFEEF3F8);
  static const Color chatInputText = Color(0xFFE8EEF5);
  static const Color chatTextMuted = Color(0xFFAEB7C4);
  static const Color chatIcon = Color(0xFF8B94A3);
  static const Color chatIconBright = Color(0xFFDDE3EB);
  static const Color chatLogoText = Color(0xFFBFD4E8);
  static const Color chatPlaceholder = Color(0xFF7B8494);
  static const Color chatDisclaimer = Color(0xFF7D8796);
  static const Color chatError = negative;
}
