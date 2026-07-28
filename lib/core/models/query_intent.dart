// QueryIntent — the structured filter object the customer AI chat produces from
// a free-text question. Prompt 1/3: PARSING ONLY (no answering logic here).
//
// Every field is nullable: the parser fills ONLY what the user actually said,
// never inventing filters. Defaults (location, distance, active child's age) are
// merged AFTER parsing, in code (see [mergeDefaults]) — never by the model.

/// What the user is trying to do.
enum QueryIntentType {
  findProviders,
  compare,
  questionAboutBooking,
  other;

  String get wire => switch (this) {
    QueryIntentType.findProviders => 'find_providers',
    QueryIntentType.compare => 'compare',
    QueryIntentType.questionAboutBooking => 'question_about_booking',
    QueryIntentType.other => 'other',
  };

  static QueryIntentType? fromWire(String? s) {
    switch (s) {
      case 'find_providers':
        return QueryIntentType.findProviders;
      case 'compare':
        return QueryIntentType.compare;
      case 'question_about_booking':
        return QueryIntentType.questionAboutBooking;
      case 'other':
        return QueryIntentType.other;
    }
    return null;
  }
}

/// How the user wants results ordered.
enum SortPreference {
  cheapest,
  closest,
  topRated,
  bestFit;

  String get wire => switch (this) {
    SortPreference.cheapest => 'cheapest',
    SortPreference.closest => 'closest',
    SortPreference.topRated => 'top_rated',
    SortPreference.bestFit => 'best_fit',
  };

  static SortPreference? fromWire(String? s) {
    switch (s) {
      case 'cheapest':
        return SortPreference.cheapest;
      case 'closest':
        return SortPreference.closest;
      case 'top_rated':
        return SortPreference.topRated;
      case 'best_fit':
        return SortPreference.bestFit;
    }
    return null;
  }
}

class QueryIntent {
  final String? sport;
  final String? sessionType; // 'one_on_one' | 'group' | ...
  final int? priceMaxCents;
  final int? priceMinCents;
  final num? maxDistanceKm;
  final int? age;
  final String? skillLevel;
  final String? availabilityWindow;
  final SortPreference? sortPreference;
  final QueryIntentType? intentType;

  /// Not produced by the parser — populated by [mergeDefaults] from the user's
  /// profile. Kept here so the executor (prompts 2–3) has the search origin.
  final String? location;

  const QueryIntent({
    this.sport,
    this.sessionType,
    this.priceMaxCents,
    this.priceMinCents,
    this.maxDistanceKm,
    this.age,
    this.skillLevel,
    this.availabilityWindow,
    this.sortPreference,
    this.intentType,
    this.location,
  });

  QueryIntent copyWith({
    String? sport,
    String? sessionType,
    int? priceMaxCents,
    int? priceMinCents,
    num? maxDistanceKm,
    int? age,
    String? skillLevel,
    String? availabilityWindow,
    SortPreference? sortPreference,
    QueryIntentType? intentType,
    String? location,
  }) => QueryIntent(
    sport: sport ?? this.sport,
    sessionType: sessionType ?? this.sessionType,
    priceMaxCents: priceMaxCents ?? this.priceMaxCents,
    priceMinCents: priceMinCents ?? this.priceMinCents,
    maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    age: age ?? this.age,
    skillLevel: skillLevel ?? this.skillLevel,
    availabilityWindow: availabilityWindow ?? this.availabilityWindow,
    sortPreference: sortPreference ?? this.sortPreference,
    intentType: intentType ?? this.intentType,
    location: location ?? this.location,
  );

  /// Merges defaults AFTER parsing (step 3) — in code, never in the model:
  /// - location from the user's profile,
  /// - a default search radius (only for provider searches),
  /// - the active child's age when the query didn't state one.
  QueryIntent mergeDefaults({
    String? profileLocation,
    num defaultDistanceKm = 40,
    int? activeChildAge,
  }) {
    final isSearch = intentType == QueryIntentType.findProviders ||
        intentType == QueryIntentType.compare;
    return copyWith(
      location: location ?? profileLocation,
      maxDistanceKm: maxDistanceKm ?? (isSearch ? defaultDistanceKm : null),
      age: age ?? (isSearch ? activeChildAge : null),
    );
  }

  factory QueryIntent.fromJson(Map<String, dynamic> j) => QueryIntent(
    sport: j['sport'] as String?,
    sessionType: j['session_type'] as String?,
    priceMaxCents: (j['price_max_cents'] as num?)?.toInt(),
    priceMinCents: (j['price_min_cents'] as num?)?.toInt(),
    maxDistanceKm: j['max_distance_km'] as num?,
    age: (j['age'] as num?)?.toInt(),
    skillLevel: j['skill_level'] as String?,
    availabilityWindow: j['availability_window'] as String?,
    sortPreference: SortPreference.fromWire(j['sort_preference'] as String?),
    intentType: QueryIntentType.fromWire(j['intent_type'] as String?),
    location: j['location'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'sport': sport,
    'session_type': sessionType,
    'price_max_cents': priceMaxCents,
    'price_min_cents': priceMinCents,
    'max_distance_km': maxDistanceKm,
    'age': age,
    'skill_level': skillLevel,
    'availability_window': availabilityWindow,
    'sort_preference': sortPreference?.wire,
    'intent_type': intentType?.wire,
    'location': location,
  };

  @override
  bool operator ==(Object other) =>
      other is QueryIntent &&
      other.sport == sport &&
      other.sessionType == sessionType &&
      other.priceMaxCents == priceMaxCents &&
      other.priceMinCents == priceMinCents &&
      other.maxDistanceKm == maxDistanceKm &&
      other.age == age &&
      other.skillLevel == skillLevel &&
      other.availabilityWindow == availabilityWindow &&
      other.sortPreference == sortPreference &&
      other.intentType == intentType &&
      other.location == location;

  @override
  int get hashCode => Object.hash(
    sport,
    sessionType,
    priceMaxCents,
    priceMinCents,
    maxDistanceKm,
    age,
    skillLevel,
    availabilityWindow,
    sortPreference,
    intentType,
    location,
  );

  @override
  String toString() => 'QueryIntent(${toJson()})';
}
