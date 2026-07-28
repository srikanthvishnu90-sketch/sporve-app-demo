import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sporve type system — **Inter** (headers/titles ≥18px) / **Hanken Grotesk**
/// (UI + body) / **JetBrains Mono** (all data/numbers), loaded via google_fonts.
/// Header sizes are intentionally restrained (reduced from the earlier scale —
/// smaller, tighter titles). All styles funnel through here (CLAUDE.md).
class AppTypography {
  /// Default app font family (Hanken Grotesk) for the MaterialApp theme.
  static String get fontFamily =>
      GoogleFonts.inter().fontFamily ?? 'HankenGrotesk';

  // ── Display / headers / titles → Inter ────────────────────────────────────
  static TextStyle _headerFont({
    required double size,
    required FontWeight weight,
    required double tracking,
    double height = 1.3,
    Color? color,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: height,
        color: color,
      );

  // ── Body / UI → Hanken Grotesk ────────────────────────────────────────────
  static TextStyle _bodyFont({
    required double size,
    required FontWeight weight,
    required double tracking,
    double height = 1.3,
    Color? color,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: height,
        color: color,
      );

  // ── Display & headlines (Inter) — sizes reduced/restrained ────────────────
  static TextStyle get displayLarge => _headerFont(
      size: 26, weight: FontWeight.w700, tracking: -0.6, height: 1.05);

  static TextStyle get display =>
      _headerFont(size: 23, weight: FontWeight.w700, tracking: -0.5, height: 1.12);

  static TextStyle get h1 =>
      _headerFont(size: 19, weight: FontWeight.w600, tracking: -0.4, height: 1.15);
  static TextStyle get heading => h1;

  static TextStyle get h2 =>
      _headerFont(size: 16, weight: FontWeight.w600, tracking: -0.3, height: 1.2);

  // ── Body — sizes unchanged ────────────────────────────────────────────────
  static TextStyle get titleMedium =>
      _bodyFont(size: 15, weight: FontWeight.w500, tracking: -0.1, height: 1.3);
  static TextStyle get bodyLarge =>
      _bodyFont(size: 15, weight: FontWeight.w400, tracking: 0, height: 1.5);
  static TextStyle get bodyMedium =>
      _bodyFont(size: 13.5, weight: FontWeight.w400, tracking: 0, height: 1.5);
  static TextStyle get bodySmall =>
      _bodyFont(size: 12.5, weight: FontWeight.w400, tracking: 0, height: 1.45);

  // ── Labels & captions — sizes unchanged ───────────────────────────────────
  static TextStyle get label =>
      _bodyFont(size: 11, weight: FontWeight.w500, tracking: 0.4, height: 1.3);
  static TextStyle get caption =>
      _bodyFont(size: 11, weight: FontWeight.w400, tracking: 0.1, height: 1.4);
  static TextStyle get valueBold =>
      _bodyFont(size: 16, weight: FontWeight.w700, tracking: -0.3, height: 1.2);

  /// Inline call sites. Headers (≥18px) render in Oswald; body/labels in Hanken
  /// Grotesk. The sizing/weight/tracking rules are preserved from before — only
  /// the faces changed.
  static TextStyle font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? wordSpacing,
    Color? backgroundColor,
    TextBaseline? textBaseline,
    List<Shadow>? shadows,
  }) {
    final w = _diet(fontWeight ?? FontWeight.w400);
    double? size = fontSize;
    if (size != null && size > 24) size = 24; // restrained header ceiling
    double? ls;
    if (size != null &&
        size >= 20 &&
        (letterSpacing == null || letterSpacing >= 0)) {
      ls = -0.4;
    } else {
      ls = _track(letterSpacing);
    }
    final family =
        (size != null && size >= 18) ? GoogleFonts.inter : GoogleFonts.inter;
    return family(
      fontSize: size,
      fontWeight: w,
      letterSpacing: ls,
      height: height,
      color: color,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      wordSpacing: wordSpacing,
      backgroundColor: backgroundColor,
      textBaseline: textBaseline,
      shadows: shadows,
    );
  }

  /// Weight diet: 700/800/900 → 600; lighter weights unchanged.
  static FontWeight _diet(FontWeight w) =>
      w.value >= FontWeight.w700.value ? FontWeight.w600 : w;

  /// Tracking diet: collapse airy caps spacing to a whisper.
  static double? _track(double? ls) => (ls != null && ls > 0.6) ? 0.4 : ls;

  /// Data / numbers → JetBrains Mono. Sizes unchanged.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.2,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: 0,
      );
}
