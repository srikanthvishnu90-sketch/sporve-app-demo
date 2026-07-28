import 'package:flutter/material.dart';
import '../../core/theme/sport_colors.dart';

/// Renders a sport as a monochrome line icon.
///
/// Historically this took a sport *emoji* string and rendered it. Emoji is the
/// loudest single childishness signal in a UI, so this now maps whatever it is
/// given — an emoji OR a sport name — to a refined `IconData` from the sport
/// icon set and renders that, inheriting the chosen [color]. All existing call
/// sites keep working unchanged; they just stop showing emoji.
class SportGlyph extends StatelessWidget {
  /// An emoji (legacy) or a sport name. Either resolves to a line icon.
  final String emoji;
  final double size;
  final Color color;

  const SportGlyph(
    this.emoji, {
    super.key,
    this.size = 20,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      SportColors.iconForEmoji(emoji),
      size: size,
      color: color,
    );
  }
}
