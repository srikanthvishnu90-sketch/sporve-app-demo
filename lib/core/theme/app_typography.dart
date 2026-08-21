import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sporve's locked type system: Oswald display, Hanken Grotesk body/UI, and
/// JetBrains Mono for money, times, counts, and other data.
class AppTypography {
  static String get fontFamily =>
      GoogleFonts.hankenGrotesk().fontFamily ?? 'Hanken Grotesk';

  static TextStyle _headerFont({
    required double size,
    required FontWeight weight,
    required double tracking,
    double height = 1.2,
    Color? color,
  }) => GoogleFonts.oswald(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: tracking < 0 ? 0 : tracking,
    height: height,
    color: color,
  );

  static TextStyle _bodyFont({
    required double size,
    required FontWeight weight,
    required double tracking,
    double height = 1.3,
    Color? color,
  }) => GoogleFonts.hankenGrotesk(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: tracking,
    height: height,
    color: color,
  );

  static TextStyle get displayLarge => _headerFont(
    size: 26,
    weight: FontWeight.w700,
    tracking: 0.2,
    height: 1.05,
  );
  static TextStyle get display => _headerFont(
    size: 23,
    weight: FontWeight.w700,
    tracking: 0.15,
    height: 1.12,
  );
  static TextStyle get h1 => _headerFont(
    size: 19,
    weight: FontWeight.w700,
    tracking: 0.1,
    height: 1.15,
  );
  static TextStyle get heading => h1;
  static TextStyle get h2 =>
      _bodyFont(size: 16, weight: FontWeight.w700, tracking: -0.1, height: 1.2);

  static TextStyle get titleMedium =>
      _bodyFont(size: 15, weight: FontWeight.w500, tracking: -0.1);
  static TextStyle get bodyLarge =>
      _bodyFont(size: 15, weight: FontWeight.w400, tracking: 0, height: 1.5);
  static TextStyle get bodyMedium =>
      _bodyFont(size: 13.5, weight: FontWeight.w400, tracking: 0, height: 1.5);
  static TextStyle get bodySmall =>
      _bodyFont(size: 12.5, weight: FontWeight.w400, tracking: 0, height: 1.45);
  static TextStyle get label =>
      _bodyFont(size: 11, weight: FontWeight.w500, tracking: 0.4);
  static TextStyle get caption =>
      _bodyFont(size: 11, weight: FontWeight.w400, tracking: 0.1, height: 1.4);
  static TextStyle get valueBold =>
      _bodyFont(size: 16, weight: FontWeight.w700, tracking: -0.2, height: 1.2);

  /// Inline compatibility API. Text at 18px and above uses Oswald; smaller UI
  /// copy uses Hanken Grotesk. Declared weights pass through unchanged.
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
    final isHeader = (fontSize ?? 0) >= 18;
    final tracking = isHeader
        ? ((letterSpacing ?? 0.1) < 0 ? 0.0 : (letterSpacing ?? 0.1))
        : letterSpacing;
    final arguments = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      letterSpacing: tracking,
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
    return (isHeader ? GoogleFonts.oswald() : GoogleFonts.hankenGrotesk())
        .merge(arguments);
  }

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.2,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: 0,
  );
}
