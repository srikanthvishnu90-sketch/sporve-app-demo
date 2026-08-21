import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/provider_trust.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/home_controller.dart';
import '../../authentication/controllers/auth_provider.dart';

/// Home hero — the AI matchmaker. Sporve's concierge presents one trainer at a
/// time, matched to the family's goal; the parent works through them one by one
/// (Pass / Save / View) to figure out who fits. Not a Hinge clone — the same
/// "one person at a time, curated by intelligence" idea, applied to youth-sports
/// coaching. Everything shown is GROUNDED in a real program row (name, sport,
/// price, rating) — the AI curates and explains, it never fabricates facts.
class BestMatchCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> matches;
  const BestMatchCarousel({super.key, required this.matches});

  @override
  State<BestMatchCarousel> createState() => _BestMatchCarouselState();
}

class _BestMatchCarouselState extends State<BestMatchCarousel> {
  int _index = 0;

  void _pass() {
    final count = widget.matches.where(providerTrusted).length;
    if (count < 2) return;
    setState(() => _index = (_index + 1) % count);
  }

  void _view(Map<String, dynamic> m) =>
      Get.toNamed(AppRoutes.sessionDetails, arguments: m);

  String? _sportOf(Map<String, dynamic> m) => m['sportType']?.toString();

  String _coachOf(Map<String, dynamic> m) =>
      (m['providerId'] is Map ? m['providerId']['businessName'] : null)
          ?.toString() ??
      'Academy';

  // A grounded, honest rationale — assembled only from fields the row actually
  // carries. Never claims a specialty or result the data doesn't support.
  String _why(
    Map<String, dynamic> m,
    String? sport,
    bool hasRating,
    String rating,
  ) {
    final parts = <String>[];
    if (sport != null && sport.isNotEmpty) parts.add('$sport coaching');
    final title = m['title']?.toString();
    if (title != null && title.isNotEmpty) parts.add('"$title"');
    parts.add(hasRating ? 'rated $rating★ by families' : 'newly listed');
    return 'Matched to your goal — ${parts.join(' · ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final trustedMatches = widget.matches.where(providerTrusted).toList();
    if (trustedMatches.isEmpty) return const SizedBox.shrink();
    final home = context.watch<HomeProvider>();
    if (_index >= trustedMatches.length) _index = 0;
    final m = trustedMatches[_index];
    final sport = _sportOf(m);
    final coach = _coachOf(m);
    final price = m['price'];
    final hasRating =
        m['averageRating'] is num && (m['averageRating'] as num) > 0;
    final rating = hasRating ? m['averageRating'].toString() : 'New';
    final accent = SportColors.of(sport);
    final id = m['_id']?.toString();
    final saved = home.isFavorite(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── AI concierge framing ──────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.slate, size: 16),
            const SizedBox(width: 6),
            Text(
              'Sporve AI',
              style: AppTypography.font(
                color: AppColors.slateText,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Text(
              '${_index + 1} of ${trustedMatches.length}',
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Based on your goal, here's who I found.",
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),

        // ── The person card ───────────────────────────────────────────────
        GestureDetector(
          onTap: () => _view(m),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: SportColors.borderOf(sport)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sport-tinted hero band (well tint — NOT the ambient token,
                // which is reserved for full-bleed splash/confirmation moments).
                Container(
                  height: 132,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.20),
                        accent.withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 18,
                        bottom: -10,
                        child: Icon(
                          SportColors.iconOf(sport),
                          size: 96,
                          color: accent.withValues(alpha: 0.28),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _pill('AI match', accent),
                            const Spacer(),
                            SportIconTile(sport ?? '', size: 44),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coach,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (hasRating) ...[
                            const Icon(
                              Icons.star,
                              color: AppColors.textPrimary,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            rating,
                            style: AppTypography.font(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '\$${price is num ? price.round() : (price ?? 0)}',
                            style: AppTypography.font(
                              color: accent,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _why(m, sport, hasRating, rating),
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── One-by-one controls ───────────────────────────────────────────
        Row(
          children: [
            _circleAction(
              icon: Icons.close,
              label: 'Pass',
              onTap: _pass,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            _circleAction(
              icon: saved ? Icons.favorite : Icons.favorite_border,
              label: saved ? 'Saved' : 'Save',
              onTap: () {
                // Soft gate (spec §3.2): guests get a few free saves. Intent
                // preservation (§3.3.3): past the allowance, defer the save so
                // it applies itself once the guest signs in. `home` is the
                // app-level provider instance — safe to call from the deferred
                // callback after this card is gone.
                if (context.read<AuthProvider>().allowSave(
                  isCurrentlySaved: saved,
                  onAuthed: () => home.toggleFavorite(id),
                )) {
                  home.toggleFavorite(id);
                }
              },
              color: saved ? accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _view(m),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View & book'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: SportColors.onColorOf(sport),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Progress dots
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(trustedMatches.length, (i) {
              final active = i == _index;
              return Container(
                width: active ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? AppColors.slate : AppColors.hairlineStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color accent) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(AppRadii.chip),
      border: Border.all(color: accent.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, size: 11, color: AppColors.onSlate),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppTypography.font(
            color: AppColors.onSlate,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );

  Widget _circleAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.pill),
    child: Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairlineStrong),
      ),
      child: Icon(icon, color: color, size: 22),
    ),
  );
}
