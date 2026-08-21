import 'dart:math' as math;
import '../models/query_intent.dart';
import '../utils/provider_trust.dart';

/// One eligible provider row returned by retrieval. Carries exactly the fields
/// the chat answer + provider cards need (spec §1). `raw` is the underlying
/// service map so the UI can deep-link to the listing.
class ProviderMatch {
  final String providerId;
  final String name; // provider/business name
  final String serviceTitle;
  final int priceCents;
  final List<String> sessionTypes;
  final num? distanceKm;
  final num ratingAvg;
  final int ratingCount;
  final String availabilitySummary;
  final String sport;
  final Map<String, dynamic> raw;

  const ProviderMatch({
    required this.providerId,
    required this.name,
    required this.serviceTitle,
    required this.priceCents,
    required this.sessionTypes,
    required this.distanceKm,
    required this.ratingAvg,
    required this.ratingCount,
    required this.availabilitySummary,
    required this.sport,
    this.raw = const {},
  });

  int get priceDollars => (priceCents / 100).round();

  /// Compact row shape passed to the answer model (facts only — the model may
  /// use nothing outside this).
  Map<String, dynamic> toRow() => {
    'provider_id': providerId,
    'name': name,
    'service_title': serviceTitle,
    'price_dollars': priceDollars,
    'session_types': sessionTypes,
    'distance_km': distanceKm == null
        ? null
        : double.parse(distanceKm!.toStringAsFixed(1)),
    'rating_avg': ratingAvg,
    'rating_count': ratingCount,
    'availability': availabilitySummary,
    'sport': sport,
  };
}

/// Retrieval-and-ranking engine (CODE, not LLM). Translates a [QueryIntent] into
/// eligible provider rows, ALWAYS applying the matching-spec hard gates:
/// verified + active, sport, age served, age-appropriate intensity ceiling,
/// distance, budget, session type. Safety gates are non-negotiable — an
/// unverified or inactive provider is NEVER returned, even if it's the best
/// match on every other axis.
class ProviderMatcher {
  // Named intensity levels map onto the numeric tier vocabulary (1=low ..
  // 3=high) used by both the age ceiling and the server's `intensity_tier`.
  static const Map<String, int> _intensityTierByName = {
    'low': 1,
    'medium': 2,
    'high': 3,
  };

  /// Catalog of high-risk sports requiring strict age/intensity safety ceilings.
  static const Set<String> _highRiskSports = {
    'boxing',
    'combat',
    'martial_arts',
    'mma',
    'wrestling',
    'gymnastics',
    'cheer',
    'tackle_football',
    'football',
    'rugby',
    'karate',
    'taekwondo',
    'judo',
    'jiu_jitsu',
    'bjj',
    'kickboxing',
  };

  /// Age-appropriate intensity ceiling: young athletes cap at low/medium.
  /// For high-risk sports (combat/contact/gymnastics), stricter ceilings apply across catalog:
  /// age < 10 caps at tier 1 (low/fundamentals only), age <= 13 caps at tier 2 (medium).
  static int _ceilingForAge(int age, {String? sport}) {
    final s = sport?.toLowerCase().trim() ?? '';
    final isHighRisk = _highRiskSports.any((hr) => s.contains(hr));
    if (isHighRisk) {
      if (age < 10) return 1;
      if (age <= 13) return 2;
      return 3;
    }
    return age < 8 ? 1 : (age <= 12 ? 2 : 3);
  }

  /// G4 intensity tier for a service, coalescing the two shapes this app sees:
  /// the server/Supabase path carries a numeric `intensity_tier`; the Flutter
  /// demo + fixtures carry a named `intensity` string ('low'/'medium'/'high').
  /// Resolve whichever is present, then fail CLOSED (tier 4 = highest) only when
  /// intensity is genuinely UNKNOWN — mirroring the server's
  /// `coalesce(intensity_tier, 4) <= max_tier`. A known-low provider must not be
  /// treated as unknown and dropped for a young athlete.
  static int _intensityTier(Map<String, dynamic> s) {
    final numeric = (s['intensity_tier'] as num?)?.toInt();
    if (numeric != null) return numeric;
    final named = s['intensity']?.toString().toLowerCase();
    final mapped = named == null ? null : _intensityTierByName[named];
    return mapped ?? 4;
  }

  static double _rad(num d) => d * math.pi / 180.0;

  static num _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static List<String> _sessionTypes(Map<String, dynamic> s) {
    final raw = s['session_types'] ?? s['sessionTypes'];
    // Normalize to the canonical vocabulary (mirrors the React matcher):
    // 'private' → 'one_on_one', everything lower-cased.
    String norm(Object? e) {
      final v = e.toString().toLowerCase();
      return v == 'private' ? 'one_on_one' : v;
    }

    if (raw is List) return raw.map(norm).toList();
    if (raw is String && raw.isNotEmpty) return [norm(raw)];
    return const [];
  }

  static List<String> _availabilityWindows(Map<String, dynamic> s) {
    final raw = s['availability_windows'] ?? s['availabilityWindows'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  /// Returns up to 10 eligible rows for [intent], ordered by the requested
  /// sort preference (default: best fit = rating). [originLat]/[originLng] are
  /// the client's location for distance computation + the distance gate.
  static List<ProviderMatch> retrieve(
    List<Map<String, dynamic>> services,
    QueryIntent intent, {
    double? originLat,
    double? originLng,
  }) {
    final out = <ProviderMatch>[];

    for (final s in services) {
      // ── HARD GATES ──────────────────────────────────────────────────────
      // Active account + verified background check (safety — never relaxed).
      if ((s['account_status'] ?? 'active').toString() != 'active') continue;
      if (!providerTrusted(s)) continue;

      // Sport.
      final sport = (s['sportType'] ?? s['sport'] ?? '').toString();
      if (intent.sport != null &&
          !sport.toLowerCase().contains(intent.sport!.toLowerCase())) {
        continue;
      }

      // Age served + age-appropriate intensity ceiling.
      if (intent.age != null) {
        final minA = (s['minimumAge'] as num?)?.toInt();
        final maxA = (s['maximumAge'] as num?)?.toInt();
        if (minA != null && intent.age! < minA) continue;
        if (maxA != null && intent.age! > maxA) continue;
        // G4 — age-appropriate intensity: read the tier (numeric column OR named
        // level), failing CLOSED only on genuinely unknown intensity (treat as
        // 4 = highest), mirroring the server (coalesce(intensity_tier,4) <=
        // max_tier) and the React matcher.
        if (_intensityTier(s) > _ceilingForAge(intent.age!, sport: sport)) {
          continue;
        }
      }

      // Budget.
      final priceCents = (((s['price'] as num?)?.toDouble() ?? 0) * 100)
          .round();
      if (intent.priceMaxCents != null && priceCents > intent.priceMaxCents!) {
        continue;
      }
      if (intent.priceMinCents != null && priceCents < intent.priceMinCents!) {
        continue;
      }

      // Session type.
      final sessionTypes = _sessionTypes(s);
      if (intent.sessionType != null &&
          !sessionTypes.contains(intent.sessionType)) {
        continue;
      }

      // Availability (soft: only excludes when the service publishes windows
      // and the requested one isn't among them; unknown availability passes).
      final windows = _availabilityWindows(s);
      if (intent.availabilityWindow != null &&
          windows.isNotEmpty &&
          !windows.contains(intent.availabilityWindow)) {
        continue;
      }

      // Distance (G6). Never claim a distance match without BOTH a real origin and
      // real listing coordinates — fail CLOSED when a radius is requested but
      // either is missing (mirrors the server + the React matcher).
      num? dist;
      final coords = s['location']?['coordinates'];
      final hasCoords = coords is List && coords.length >= 2;
      if (intent.maxDistanceKm != null &&
          (originLat == null || originLng == null || !hasCoords)) {
        continue;
      }
      if (originLat != null && originLng != null && hasCoords) {
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        dist = _haversineKm(originLat, originLng, lat, lng);
        if (intent.maxDistanceKm != null && dist > intent.maxDistanceKm!) {
          continue;
        }
      }

      final prov = s['providerId'];
      final name =
          (s['providerName'] ??
                  (prov is Map ? prov['businessName'] : null) ??
                  'Coach')
              .toString();
      out.add(
        ProviderMatch(
          providerId: (s['provider_id'] ?? s['_id'] ?? name).toString(),
          name: name,
          serviceTitle: (s['title'] ?? 'Program').toString(),
          priceCents: priceCents,
          sessionTypes: sessionTypes,
          distanceKm: dist,
          ratingAvg: (s['averageRating'] as num?) ?? 0,
          ratingCount: (s['totalReviews'] as num?)?.toInt() ?? 0,
          availabilitySummary: windows.isEmpty
              ? 'Availability on request'
              : windows.map(_prettyWindow).join(', '),
          sport: sport,
          raw: s,
        ),
      );
    }

    final ranked = sort(out, intent.sortPreference);
    // One result per business (matches the React matcher + product contract):
    // a single organization can't crowd out local alternatives.
    final seen = <String>{};
    final unique = ranked.where((m) => seen.add(m.name.toLowerCase())).toList();
    return unique.take(10).toList();
  }

  /// Re-orders a result set WITHOUT re-retrieving — used for grounded follow-ups
  /// ("which of those is closest?").
  static List<ProviderMatch> sort(
    List<ProviderMatch> rows,
    SortPreference? pref,
  ) {
    final copy = List<ProviderMatch>.from(rows);
    switch (pref) {
      case SortPreference.cheapest:
        copy.sort((a, b) => a.priceCents.compareTo(b.priceCents));
      case SortPreference.closest:
        copy.sort(
          (a, b) => (a.distanceKm ?? double.infinity).compareTo(
            b.distanceKm ?? double.infinity,
          ),
        );
      case SortPreference.topRated:
        copy.sort((a, b) {
          final r = b.ratingAvg.compareTo(a.ratingAvg);
          return r != 0 ? r : b.ratingCount.compareTo(a.ratingCount);
        });
      case SortPreference.bestFit:
      case null:
        copy.sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
    }
    return copy;
  }

  static String _prettyWindow(String w) => switch (w) {
    'this_weekend' => 'This weekend',
    'this_week' => 'This week',
    'weekdays' => 'Weekdays',
    'today' => 'Today',
    'tomorrow' => 'Tomorrow',
    'evenings' => 'Evenings',
    'mornings' => 'Mornings',
    'after_school' => 'After school',
    _ => w,
  };
}
