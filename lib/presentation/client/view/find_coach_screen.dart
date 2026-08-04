import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/match_provider.dart';
import 'search_screen.dart' show Opportunity;

/// Guided coach matching — a parent selects structured athlete criteria, and
/// the ai-match engine returns safety-gated, LTAD-appropriate coaches ranked
/// deterministically from rating evidence, distance, price, and availability.
/// Distinct from the search bar (free-text); all gating and ranking is
/// server-side.
class FindCoachScreen extends StatefulWidget {
  const FindCoachScreen({super.key});

  @override
  State<FindCoachScreen> createState() => _FindCoachScreenState();
}

class _FindCoachScreenState extends State<FindCoachScreen> {
  // Demo market: all seeded providers are in Chicago, so we anchor the search
  // there (real deployment would use the family's location).
  static const double _chiLat = 41.8781;
  static const double _chiLng = -87.6298;

  static const _sports = ['Basketball', 'Soccer', 'Baseball', 'Tennis'];
  static const _skills = ['beginner', 'intermediate', 'advanced', 'elite'];

  String? _sport;
  int _age = 11;
  String? _skill;
  double _budget = 0; // dollars; 0 = "Any"

  // Explore sort (§13). "Best fit" keeps the server's deterministic ranking;
  // the others re-order the same eligible set client-side.
  static const _sorts = ['Best fit', 'Closest', 'Cheapest', 'Top rated'];
  String _sort = 'Best fit';

  void _submit() {
    if (_sport == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _sort = 'Best fit'); // fresh search returns to ranked order
    final client = <String, dynamic>{
      'athlete_age': _age,
      'sport': _sport,
      if (_skill != null) 'skill_level': _skill,
      if (_budget > 0) 'budget_max_per_session': (_budget * 100).round(),
      'session_type_pref': 'any',
      'lat': _chiLat,
      'lng': _chiLng,
      'max_distance_km': 60,
    };
    context.read<MatchProvider>().findMatches(client);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Sport'),
                    _chipRow(
                      _sports,
                      selected: _sport,
                      onTap: (s) => setState(() => _sport = s),
                      colorFor: (s) => SportColors.of(s),
                    ),
                    const SizedBox(height: 22),
                    _label('Athlete age — $_age'),
                    Slider(
                      value: _age.toDouble(),
                      min: 4,
                      max: 18,
                      divisions: 14,
                      activeColor: AppColors.slateText,
                      label: '$_age',
                      onChanged: (v) => setState(() => _age = v.round()),
                    ),
                    const SizedBox(height: 12),
                    _label('Skill level (optional)'),
                    _chipRow(
                      _skills,
                      selected: _skill,
                      labelFor: _cap,
                      onTap: (s) =>
                          setState(() => _skill = _skill == s ? null : s),
                    ),
                    const SizedBox(height: 22),
                    _label(
                      _budget > 0
                          ? 'Max per session — \$${_budget.round()}'
                          : 'Max per session — Any',
                    ),
                    Slider(
                      value: _budget,
                      min: 0,
                      max: 200,
                      divisions: 20,
                      activeColor: AppColors.slateText,
                      label: _budget > 0 ? '\$${_budget.round()}' : 'Any',
                      onChanged: (v) => setState(() => _budget = v),
                    ),
                    const SizedBox(height: 24),
                    Consumer<MatchProvider>(
                      builder: (_, m, _) => SporveButton(
                        'Find matches',
                        icon: Icons.auto_awesome,
                        loading: m.isBusy,
                        onPressed: _sport == null ? null : _submit,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _results(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
    child: Row(
      children: [
        SporveIconButton(
          Icons.arrow_back,
          semanticLabel: 'Back',
          onTap: () => Get.back(),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find your coach',
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Deterministic ranking · safety-checked · nationwide',
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _results() {
    return Consumer<MatchProvider>(
      builder: (_, m, _) {
        if (m.isBusy) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonList(count: 4),
          );
        }
        if (m.error != null) {
          return ErrorRetry(message: m.error!, onRetry: _submit);
        }
        if (!m.hasSearched) return const SizedBox.shrink();
        if (m.matches.isEmpty) {
          return Column(
            children: [
              EmptyState(
                icon: Icons.search_off_outlined,
                title: 'No verified matches in this area',
                message: m.note.isNotEmpty
                    ? m.note
                    : 'No verified, age-appropriate matches within your filters. '
                          'Try widening distance or budget — we never relax the '
                          'safety or age gates.',
              ),
              const SizedBox(height: 12),
              UnservedWaitlistCard(sport: _sport),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.matches.length} eligible coach${m.matches.length == 1 ? '' : 'es'}, ranked deterministically',
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Uses rating evidence, distance, price & availability',
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 11,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            _sortBar(),
            const SizedBox(height: 12),
            ..._sortedMatches(m.matches).asMap().entries.map(
              (e) => _matchCard(e.key + 1, e.value),
            ),
          ],
        );
      },
    );
  }

  // Re-orders the eligible set for the selected sort. "Best fit" preserves the
  // server's deterministic ranking; distance/price sort ascending, rating desc.
  List<Map> _sortedMatches(List<dynamic> matches) {
    final list = matches.whereType<Map>().toList();
    double n(dynamic v, double fallback) =>
        v is num ? v.toDouble() : fallback;
    switch (_sort) {
      case 'Closest':
        list.sort((a, b) => n(a['distance_km'], double.infinity)
            .compareTo(n(b['distance_km'], double.infinity)));
        break;
      case 'Cheapest':
        list.sort((a, b) => n(a['price_per_session'], double.infinity)
            .compareTo(n(b['price_per_session'], double.infinity)));
        break;
      case 'Top rated':
        list.sort((a, b) {
          final byRating =
              n(b['rating_avg'], 0).compareTo(n(a['rating_avg'], 0));
          if (byRating != 0) return byRating;
          return n(b['rating_count'], 0).compareTo(n(a['rating_count'], 0));
        });
        break;
      default:
        break; // Best fit — keep server order.
    }
    return list;
  }

  Widget _sortBar() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _sorts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _sorts[i];
          final isSel = _sort == s;
          return GestureDetector(
            onTap: () => setState(() => _sort = s),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSel ? AppColors.slateTint : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(
                  color: isSel ? AppColors.slateBorder : AppColors.hairline,
                  width: isSel ? 1.4 : 1,
                ),
              ),
              child: Text(
                s,
                style: AppTypography.font(
                  color:
                      isSel ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _matchCard(int rank, Map r) {
    final name = (r['name'] ?? r['title'] ?? 'Coach').toString();
    final sport = (r['sport'] ?? '').toString();
    final cents = r['price_per_session'];
    final price = cents is num ? (cents / 100).round() : null;
    final rating = r['rating_avg'];
    final ratingCount = r['rating_count'];
    final km = r['distance_km'];
    final miles = km is num ? (km * 0.621371).round() : null;
    final avail = r['available_this_week'] == true;
    final why = r['why']?.toString();
    final score = (r['score'] as num?)?.round();

    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.sessionDetails,
        arguments: _opportunity(r),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border(
            left: BorderSide(color: SportColors.of(sport), width: 3),
            top: const BorderSide(color: AppColors.hairline),
            right: const BorderSide(color: AppColors.hairline),
            bottom: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.slateTint,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: AppTypography.mono(
                      color: AppColors.slateText,
                      size: 11,
                      weight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (score != null && score > 0) ...[
                  const SizedBox(width: 8),
                  _scoreBadge(score),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (sport.isNotEmpty) SportTag(_cap(sport)),
                if (price != null)
                  _fact(Icons.payments_outlined, '\$$price', mono: true),
                if (rating != null && '$rating'.isNotEmpty && '$rating' != '0')
                  _fact(
                    Icons.star,
                    '$rating${ratingCount != null && '$ratingCount' != '0' ? ' ($ratingCount)' : ''}',
                    mono: true,
                  ),
                if (miles != null)
                  _fact(Icons.place_outlined, '$miles mi', mono: true),
                if (avail) _fact(Icons.event_available, 'This week'),
              ],
            ),
            if (why != null && why.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.slateTint,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.slateText,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        why,
                        style: AppTypography.font(
                          color: AppColors.slateText,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Deterministic 0-100 ranking score using rating evidence, distance, price,
  // and availability. Higher scores read green.
  Widget _scoreBadge(int score) {
    final c = score >= 80 ? AppColors.successGreen : AppColors.slateText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: AppTypography.mono(
              color: c,
              size: 14,
              weight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'SCORE',
            style: AppTypography.font(
              color: c,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String text, {bool mono = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 3),
      Text(
        text,
        style: mono
            ? AppTypography.mono(
                color: AppColors.textSecondary,
                size: 12,
              )
            : AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
      ),
    ],
  );

  Opportunity _opportunity(Map r) {
    final cents = r['price_per_session'];
    final price = cents is num ? (cents / 100).round() : 0;
    return Opportunity(
      id: 0,
      programId: r['provider_id']?.toString(), // == program id in ai-match
      title: (r['title'] ?? r['name'] ?? 'Program').toString(),
      coach: (r['name'] ?? '').toString(),
      price: '\$$price',
      rating: '${r['rating_avg'] ?? ''}',
      image: '',
      spotsLeft: '',
      isVerified: false,
      bookingTrend: '',
      top: 0,
      team: '',
      rawData: Map<String, dynamic>.from(r),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppTypography.font(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _chipRow(
    List<String> items, {
    required String? selected,
    required void Function(String) onTap,
    String Function(String)? labelFor,
    Color Function(String)? colorFor,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((s) {
        final isSel = selected == s;
        final accent = colorFor?.call(s) ?? AppColors.slateText;
        return GestureDetector(
          onTap: () => onTap(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSel ? AppColors.slateTint : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              border: Border.all(
                color: isSel ? accent : AppColors.hairline,
                width: isSel ? 1.4 : 1,
              ),
            ),
            child: Text(
              labelFor?.call(s) ?? s,
              style: AppTypography.font(
                color: isSel ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
