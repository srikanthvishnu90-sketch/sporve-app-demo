import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/sport_colors.dart';

/// TEMPORARY proof surface (Part 7 of the color recalibration). Renders, on the
/// real #000000 canvas: the obsidian neutral stack, every sport tile
/// (well + border + glyph), the same row with bloom, and destructive-red /
/// trust-gold beside the nearest sport colors to eyeball the collision guards.
/// Route: /debug/palette. Delete once the palette is approved.
class PaletteScreen extends StatelessWidget {
  const PaletteScreen({super.key});

  // One entry per DISTINCT calibrated base (26 families).
  static const List<String> _sports = [
    'Basketball', 'Baseball', 'Tennis', 'Rowing', 'Soccer', 'Badminton',
    'Boxing', 'Football', 'Swimming', 'Track & Field', 'Water Polo',
    'Gymnastics', 'Ice Hockey', 'Martial Arts', 'Skiing', 'Fencing', 'Golf',
    'Volleyball', 'Lacrosse', 'Dance', 'Cricket', 'Cheerleading', 'Cycling',
    'Softball', 'Climbing', 'Wrestling',
  ];

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink, // pure #000000
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          'debug / palette',
          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _section('1 · Obsidian neutral stack'),
          _neutralRow('canvas', AppColors.ink, '#000000'),
          _neutralRow('surface-1', AppColors.surface, '#0D0D0D'),
          _neutralRow('surface-2', AppColors.surface2, '#141414'),
          _neutralRow('surface-3', AppColors.surface3, '#1C1C1C'),
          _neutralRow('text primary', AppColors.textPrimary, '#F7F7F7'),
          _neutralRow('text secondary', AppColors.textSecondary, '#A3A3A3'),
          _neutralRow('text muted', AppColors.textTertiary, '#6B6B6B'),
          _neutralRow('slate (brand)', AppColors.slate, '#647B8F'),

          const SizedBox(height: 28),
          _section('2 · Sport tiles — well + border + glyph (on #000)'),
          _tileGrid(bloom: false),

          const SizedBox(height: 28),
          _section('3 · Same tiles, bloom enabled'),
          _tileGrid(bloom: true),

          const SizedBox(height: 28),
          _section('4 · Reserved vs nearest sport (collision guard)'),
          _reservedRow(),

          const SizedBox(height: 20),
          _section('Squint test'),
          Text(
            'No tile should read louder than its neighbors. Anchor (Basketball) '
            'is the reference. Destructive red and trust gold must stay '
            'unmistakably distinct from every sport tile.',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      t,
      style: AppTypography.font(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _neutralRow(String label, Color c, String hex) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.hairlineStrong),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          hex,
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Widget _tileGrid({required bool bloom}) => Wrap(
    spacing: 12,
    runSpacing: 14,
    children: [for (final s in _sports) _tile(s, bloom: bloom)],
  );

  Widget _tile(String sport, {required bool bloom}) {
    final base = SportColors.of(sport);
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: SportColors.wellOf(sport), // 8%
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SportColors.borderOf(sport)), // 45%
              boxShadow: bloom ? SportColors.bloomOf(sport) : null, // 38% / off
            ),
            child: Icon(
              SportColors.iconOf(sport),
              color: base, // glyph 100%
              size: 26,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sport,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 9.5,
              height: 1.15,
            ),
          ),
          Text(
            _hex(base),
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reservedRow() => Wrap(
    spacing: 12,
    runSpacing: 14,
    children: [
      _swatch('Destructive\nRed', AppColors.destructiveRed, '#EF4444'),
      _swatch('Wrestling', SportColors.of('wrestling'), null),
      _swatch('Boxing', SportColors.of('boxing'), null),
      _swatch('Volleyball', SportColors.of('volleyball'), null),
      const SizedBox(width: 8),
      _swatch('Trust\nGold', AppColors.trustGold, '#D4A94E'),
      _swatch('Softball', SportColors.of('softball'), null),
      _swatch('Football', SportColors.of('football'), null),
      _swatch('Tennis', SportColors.of('tennis'), null),
    ],
  );

  Widget _swatch(String label, Color c, String? hex) => SizedBox(
    width: 70,
    child: Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairlineStrong),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 9.5,
            height: 1.15,
          ),
        ),
        Text(
          hex ?? _hex(c),
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 8.5,
          ),
        ),
      ],
    ),
  );
}
