/// Spacing & radius scale for Sporve.
///
/// A single 4-pt based scale keeps padding/gaps consistent across screens —
/// part of what gives Uber/Kalshi their tidy, minimalist rhythm. Use these
/// instead of scattering magic numbers.
class AppSizes {
  // Spacing (4-pt scale)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Screen edge padding
  static const double screenPadding = 24;

  // Corner radii — tightened to the Kalshi/Robinhood register (see AppRadii).
  // Large rounding reads childish; these legacy names now map to tight values
  // so every screen referencing them snaps to the new scale automatically.
  static const double radiusSm = 6; // chips / badges
  static const double radiusMd = 8; // tiles / buttons / inputs / pills
  static const double radiusLg = 10; // cards / rows
  static const double radiusXl = 10; // cards (was 32 — never larger)
  static const double radiusPill = 999; // entry buttons + avatars only
}
