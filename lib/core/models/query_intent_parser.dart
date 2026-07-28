import 'query_intent.dart';

/// Deterministic, rules-based parser for the customer AI chat.
///
/// This is the OFFLINE/reference implementation of the query parser: the
/// production path is the `chat-parse-query` Edge Function (one LLM call, cheap
/// tier, tool-constrained JSON). This class mirrors its contract exactly so the
/// mock demo talks the same shape and the parse can be unit-tested
/// deterministically. Like the model, it extracts ONLY what the user said and
/// never invents a filter; unstated fields stay null.
class QueryIntentParser {
  static const List<String> _sports = [
    'basketball', 'soccer', 'football', 'tennis', 'baseball', 'softball',
    'volleyball', 'swimming', 'diving', 'water polo', 'golf', 'lacrosse',
    'wrestling', 'boxing', 'martial arts', 'mma', 'karate', 'judo', 'taekwondo',
    'gymnastics', 'track', 'cross country', 'hockey', 'ice hockey', 'fencing',
    'badminton', 'pickleball', 'squash', 'cricket', 'cheer', 'cheerleading',
    'dance', 'cycling', 'climbing', 'rowing', 'surfing', 'skiing', 'snowboarding',
  ];

  static QueryIntent parse(String raw) {
    final q = raw.toLowerCase().trim();

    final sessionType = _sessionType(q);
    final sport = _sport(q);
    final priceMax = _priceMax(q);
    final priceMin = _priceMin(q);
    final age = _age(q);
    final sort = _sort(q);
    final avail = _availability(q);
    final distance = _distanceKm(q);
    final skill = _skill(q);

    QueryIntentType intent;
    if (RegExp(r'\bcompare\b|\bvs\.?\b|difference between').hasMatch(q)) {
      intent = QueryIntentType.compare;
    } else if (_isBookingQuestion(q)) {
      intent = QueryIntentType.questionAboutBooking;
    } else if (sport != null ||
        priceMax != null ||
        priceMin != null ||
        age != null ||
        sort != null ||
        avail != null ||
        sessionType != null ||
        distance != null ||
        skill != null ||
        _looksLikeFind(q)) {
      intent = QueryIntentType.findProviders;
    } else {
      intent = QueryIntentType.other;
    }

    // Provider searches AND comparisons carry filters (so "compare the two
    // basketball coaches under $50" stays scoped); question/other clear them.
    final keep = intent == QueryIntentType.findProviders ||
        intent == QueryIntentType.compare;
    return QueryIntent(
      intentType: intent,
      sport: keep ? sport : null,
      sessionType: keep ? sessionType : null,
      priceMaxCents: keep ? priceMax : null,
      priceMinCents: keep ? priceMin : null,
      maxDistanceKm: keep ? distance : null,
      age: keep ? age : null,
      skillLevel: keep ? skill : null,
      availabilityWindow: keep ? avail : null,
      sortPreference: keep ? sort : null,
    );
  }

  static String? _sessionType(String q) {
    if (RegExp(
      r'private lesson|1[\s-]*on[\s-]*1|one[\s-]*on[\s-]*one|individual training|individual lesson|\bindividual\b|solo training',
    ).hasMatch(q)) {
      return 'one_on_one';
    }
    if (RegExp(r'\bgroup\b|team training|group class').hasMatch(q)) {
      return 'group';
    }
    return null;
  }

  static String? _sport(String q) {
    for (final s in _sports) {
      if (RegExp('\\b${RegExp.escape(s)}\\b').hasMatch(q)) return s;
    }
    return null;
  }

  static int? _priceMax(String q) {
    final m = RegExp(
      r'(?:under|below|less than|up to|max(?:imum)?|no more than|cheaper than|<)\s*\$?\s*(\d+(?:\.\d+)?)',
    ).firstMatch(q);
    return m == null ? null : (double.parse(m.group(1)!) * 100).round();
  }

  static int? _priceMin(String q) {
    final m = RegExp(
      r'(?:over|above|at least|more than|min(?:imum)?|starting at|>)\s*\$?\s*(\d+(?:\.\d+)?)',
    ).firstMatch(q);
    return m == null ? null : (double.parse(m.group(1)!) * 100).round();
  }

  static int? _age(String q) {
    final m = RegExp(
      r'(\d{1,2})[\s-]*(?:year|yr|yo)s?(?:[\s-]*old)?',
    ).firstMatch(q);
    if (m != null) return int.tryParse(m.group(1)!);
    final m2 = RegExp(r'\bage(?:d)?\s*(\d{1,2})\b').firstMatch(q);
    return m2 == null ? null : int.tryParse(m2.group(1)!);
  }

  static SortPreference? _sort(String q) {
    if (RegExp(r'cheapest|least expensive|lowest price|most affordable')
        .hasMatch(q)) {
      return SortPreference.cheapest;
    }
    if (RegExp(r'closest|nearest|near me|nearby').hasMatch(q)) {
      return SortPreference.closest;
    }
    if (RegExp(r'top[\s-]*rated|highest[\s-]*rated|best[\s-]*rated|best reviews')
        .hasMatch(q)) {
      return SortPreference.topRated;
    }
    if (RegExp(r'best fit|best match').hasMatch(q)) {
      return SortPreference.bestFit;
    }
    return null;
  }

  static String? _availability(String q) {
    if (RegExp(r'this weekend|\bweekend\b').hasMatch(q)) return 'this_weekend';
    if (q.contains('today')) return 'today';
    if (q.contains('tomorrow')) return 'tomorrow';
    if (q.contains('this week')) return 'this_week';
    if (q.contains('weekday')) return 'weekdays';
    if (RegExp(r'after school|evening|mornings?').hasMatch(q)) {
      return RegExp(r'after school').hasMatch(q)
          ? 'after_school'
          : (q.contains('evening') ? 'evenings' : 'mornings');
    }
    return null;
  }

  static num? _distanceKm(String q) {
    final m = RegExp(
      r'(?:within|under|less than|up to)?\s*(\d+(?:\.\d+)?)\s*(miles?|mi|km|kilometers?)',
    ).firstMatch(q);
    if (m == null) return null;
    final v = double.parse(m.group(1)!);
    final unit = m.group(2)!;
    final km = unit.startsWith('mi') ? v * 1.60934 : v;
    return double.parse(km.toStringAsFixed(1));
  }

  static String? _skill(String q) {
    if (q.contains('beginner')) return 'beginner';
    if (q.contains('intermediate')) return 'intermediate';
    if (q.contains('advanced') || q.contains('elite')) return 'advanced';
    if (q.contains('all levels')) return 'all_levels';
    return null;
  }

  static bool _isBookingQuestion(String q) => RegExp(
    r'refund|cancel|cancellation|reschedul|payment|charge|receipt|invoice|waitlist|policy|how (?:do|does|can) i (?:book|pay|cancel|reschedule)|how does booking',
  ).hasMatch(q);

  static bool _looksLikeFind(String q) => RegExp(
    r'\bfind\b|\btrainer\b|\bcoach(?:es)?\b|\bcompan(?:y|ies)\b|\bacadem(?:y|ies)\b|available|near me|\bwho\b|looking for',
  ).hasMatch(q);
}
