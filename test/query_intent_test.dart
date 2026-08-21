import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/models/query_intent.dart';
import 'package:sporve_app/core/models/query_intent_parser.dart';

void main() {
  group('QueryIntentParser — golden queries (exact, no hallucination)', () {
    test('"companies with private lessons under \$75"', () {
      expect(
        QueryIntentParser.parse('companies with private lessons under \$75'),
        const QueryIntent(
          intentType: QueryIntentType.findProviders,
          sessionType: 'one_on_one',
          priceMaxCents: 7500,
        ),
      );
    });

    test('"cheapest basketball trainer for my 12 year old"', () {
      expect(
        QueryIntentParser.parse('cheapest basketball trainer for my 12 year old'),
        const QueryIntent(
          intentType: QueryIntentType.findProviders,
          sport: 'basketball',
          age: 12,
          sortPreference: SortPreference.cheapest,
        ),
      );
    });

    test('"who\'s available this weekend"', () {
      expect(
        QueryIntentParser.parse("who's available this weekend"),
        const QueryIntent(
          intentType: QueryIntentType.findProviders,
          availabilityWindow: 'this_weekend',
        ),
      );
    });

    test('"compare the two trainers I looked at" → compare, filters null', () {
      expect(
        QueryIntentParser.parse('compare the two trainers I looked at'),
        const QueryIntent(intentType: QueryIntentType.compare),
      );
    });

    test('"how do refunds work" → question_about_booking, all null', () {
      expect(
        QueryIntentParser.parse('how do refunds work'),
        const QueryIntent(intentType: QueryIntentType.questionAboutBooking),
      );
    });
  });

  group('No hallucination — unstated fields stay null', () {
    test('price query does not invent a sport or sort', () {
      final r = QueryIntentParser.parse('anything under \$50');
      expect(r.priceMaxCents, 5000);
      expect(r.sport, isNull);
      expect(r.sortPreference, isNull);
      expect(r.age, isNull);
      expect(r.maxDistanceKm, isNull);
    });

    test('normalizes distance in miles to km', () {
      final r = QueryIntentParser.parse('soccer coach within 10 miles');
      expect(r.sport, 'soccer');
      expect(r.maxDistanceKm, closeTo(16.1, 0.1));
    });
  });

  group('QueryIntent JSON round-trip', () {
    test('toJson/fromJson is lossless', () {
      const intent = QueryIntent(
        sport: 'tennis',
        sessionType: 'one_on_one',
        priceMaxCents: 12000,
        priceMinCents: 3000,
        maxDistanceKm: 40,
        age: 14,
        skillLevel: 'beginner',
        availabilityWindow: 'this_weekend',
        sortPreference: SortPreference.topRated,
        intentType: QueryIntentType.findProviders,
        location: 'Miami, FL',
      );
      expect(QueryIntent.fromJson(intent.toJson()), intent);
    });
  });

  group('mergeDefaults — applied in code, after parsing', () {
    test('fills location, radius (40), and active child age for a find query', () {
      final parsed = QueryIntentParser.parse('basketball trainer');
      final merged = parsed.mergeDefaults(
        profileLocation: 'Miami, FL',
        activeChildAge: 10,
      );
      expect(merged.location, 'Miami, FL');
      expect(merged.maxDistanceKm, 40);
      expect(merged.age, 10);
    });

    test('does not override values the user explicitly stated', () {
      final parsed = QueryIntentParser.parse(
        'basketball trainer for my 12 year old within 5 miles',
      );
      final merged = parsed.mergeDefaults(
        profileLocation: 'Miami, FL',
        activeChildAge: 10,
      );
      expect(merged.age, 12); // kept, not overwritten by 10
      expect(merged.maxDistanceKm, closeTo(8.0, 0.2)); // 5 miles, not 40
    });

    test('non-find intents do not get a search radius or age default', () {
      final parsed = QueryIntentParser.parse('how do refunds work');
      final merged = parsed.mergeDefaults(
        profileLocation: 'Miami, FL',
        activeChildAge: 10,
      );
      expect(merged.intentType, QueryIntentType.questionAboutBooking);
      expect(merged.maxDistanceKm, isNull);
      expect(merged.age, isNull);
      expect(merged.location, 'Miami, FL'); // location still merged
    });
  });
}
