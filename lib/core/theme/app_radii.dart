/// Corner-radius scale for Sporve.
///
/// Tight radii are a core premium signal — large rounding is a primary cause of
/// the "childish" read this system fights. Cards/rows 10, tiles/buttons/inputs/
/// pills 8, small chips/badges 6. Full pills (999) are reserved exclusively for
/// the Layer-1 entry buttons (social sign-in / get-started) and avatar circles.
class AppRadii {
  static const double card = 10; // cards, rows
  static const double tile = 8; // tiles, buttons, inputs, pills
  static const double chip = 6; // small chips / badges
  static const double pill = 999; // ENTRY buttons + avatars ONLY
}
