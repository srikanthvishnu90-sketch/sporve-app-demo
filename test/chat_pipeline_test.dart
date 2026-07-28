import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/models/query_intent.dart';
import 'package:flutter_structure/core/models/query_intent_parser.dart';
import 'package:flutter_structure/core/matching/provider_matcher.dart';
import 'package:flutter_structure/core/data/mock_repository.dart';
import 'package:flutter_structure/core/data/policies.dart';

/// Builds one seeded service in the mock program shape.
Map<String, dynamic> svc({
  required String id,
  required String name,
  required bool verified,
  required num price,
  required List<String> session,
  String sport = 'tennis',
  int minAge = 5,
  int maxAge = 18,
  String intensity = 'medium',
  List<String> availability = const ['this_weekend', 'weekdays'],
  double? lat,
  double? lng,
  num rating = 4.7,
  int reviews = 10,
  String account = 'active',
}) => {
  '_id': id,
  'title': '$name Program',
  'providerId': {
    'businessName': name,
    'verificationStatus': verified ? 'verified' : 'pending',
    'background_check_status': verified ? 'verified' : 'pending',
  },
  'price': price,
  'session_types': session,
  'sportType': sport,
  'minimumAge': minAge,
  'maximumAge': maxAge,
  'intensity': intensity,
  'availability_windows': availability,
  'averageRating': rating,
  'totalReviews': reviews,
  'account_status': account,
  if (lat != null && lng != null)
    'location': {
      'type': 'Point',
      'coordinates': [lng, lat],
    },
};

// The acceptance scenario seed: some 1-on-1 under $75, some over, some group,
// one unverified.
final _seed = <Map<String, dynamic>>[
  svc(id: 's1', name: 'Apex', verified: true, price: 60, session: ['one_on_one', 'group'], sport: 'basketball'),
  svc(id: 's2', name: 'Coral', verified: true, price: 90, session: ['one_on_one'], sport: 'tennis'),
  svc(id: 's3', name: 'Downtown', verified: true, price: 40, session: ['group'], sport: 'soccer'),
  svc(id: 's4', name: 'Everglade', verified: false, price: 50, session: ['one_on_one'], sport: 'tennis'),
  svc(id: 's5', name: 'Ironside', verified: true, price: 45, session: ['one_on_one', 'group'], sport: 'boxing'),
  svc(id: 's6', name: 'Sunset', verified: true, price: 70, session: ['one_on_one'], sport: 'baseball'),
];

void main() {
  group('ACCEPTANCE (prompt 2): "private lessons under \$75"', () {
    test('returns ONLY eligible under-\$75 1-on-1; unverified never appears', () {
      final intent = QueryIntentParser.parse('what companies have private lessons under \$75');
      final rows = ProviderMatcher.retrieve(_seed, intent);
      final names = rows.map((r) => r.name).toSet();

      expect(names, {'Apex', 'Ironside', 'Sunset'});
      expect(names.contains('Everglade'), isFalse, reason: 'unverified excluded');
      expect(names.contains('Coral'), isFalse, reason: '\$90 over budget');
      expect(names.contains('Downtown'), isFalse, reason: 'group-only');
      expect(rows.every((r) => r.priceCents <= 7500), isTrue);
      expect(rows.every((r) => r.sessionTypes.contains('one_on_one')), isTrue);
      // Prices match the seed exactly (nothing fabricated).
      expect(rows.firstWhere((r) => r.name == 'Apex').priceDollars, 60);
      expect(rows.firstWhere((r) => r.name == 'Ironside').priceDollars, 45);
    });

    test('impossible budget ("under \$5") → empty (honest no-match)', () {
      final rows = ProviderMatcher.retrieve(
        _seed,
        QueryIntentParser.parse('private lessons under \$5'),
      );
      expect(rows, isEmpty);
    });
  });

  group('Hard safety gate', () {
    test('an unverified provider is excluded even when it is the cheapest', () {
      // Everglade (\$50, unverified) would top a cheapest sort — must not appear.
      final rows = ProviderMatcher.retrieve(
        _seed,
        QueryIntentParser.parse('cheapest private lessons'),
      );
      expect(rows.first.name, 'Ironside'); // \$45, verified
      expect(rows.map((r) => r.name), isNot(contains('Everglade')));
    });

    test('identity verification alone never satisfies the background check', () {
      final identityOnly = svc(
        id: 'identity-only',
        name: 'Identity Only',
        verified: true,
        price: 10,
        session: ['one_on_one'],
      );
      (identityOnly['providerId'] as Map<String, dynamic>)
          .remove('background_check_status');

      final rows = ProviderMatcher.retrieve(
        [identityOnly],
        QueryIntentParser.parse('cheapest private lessons'),
      );

      expect(rows, isEmpty);
    });
  });

  group('Filters (prompt 3 regression)', () {
    test('sport + age: intensity ceiling + age-served gate', () {
      final ageSeed = [
        svc(id: 'b1', name: 'HardCourt', verified: true, price: 50, session: ['one_on_one'], sport: 'basketball', minAge: 6, maxAge: 10, intensity: 'high'),
        svc(id: 'b2', name: 'EasyHoops', verified: true, price: 55, session: ['one_on_one'], sport: 'basketball', minAge: 6, maxAge: 12, intensity: 'low'),
        svc(id: 'b3', name: 'TeenBall', verified: true, price: 45, session: ['one_on_one'], sport: 'basketball', minAge: 13, maxAge: 18, intensity: 'medium'),
      ];
      final rows = ProviderMatcher.retrieve(
        ageSeed,
        QueryIntentParser.parse('basketball trainer for my 7 year old'),
      );
      expect(rows.map((r) => r.name).toSet(), {'EasyHoops'});
    });

    test('availability: "this weekend" excludes weekday-only services', () {
      final availSeed = [
        svc(id: 'a1', name: 'WeekendCo', verified: true, price: 50, session: ['group'], sport: 'soccer', availability: ['this_weekend']),
        svc(id: 'a2', name: 'WeekdayCo', verified: true, price: 50, session: ['group'], sport: 'soccer', availability: ['weekdays']),
      ];
      final rows = ProviderMatcher.retrieve(
        availSeed,
        QueryIntentParser.parse('soccer coaches available this weekend'),
      );
      expect(rows.map((r) => r.name).toSet(), {'WeekendCo'});
    });

    test('comparison: intent=compare still excludes the unverified provider', () {
      final intent = QueryIntentParser.parse('compare Apex and Ironside');
      expect(intent.intentType, QueryIntentType.compare);
      final rows = ProviderMatcher.retrieve(_seed, intent);
      expect(rows.map((r) => r.name), isNot(contains('Everglade')));
      expect(rows.length, greaterThanOrEqualTo(2));
    });
  });

  group('Follow-up re-sort (grounded, no re-retrieval)', () {
    test('"which of those is closest?" re-sorts the prior set by distance', () {
      final distSeed = [
        svc(id: 'd1', name: 'Far', verified: true, price: 50, session: ['group'], sport: 'golf', lat: 25.90, lng: -80.30),
        svc(id: 'd2', name: 'Near', verified: true, price: 60, session: ['group'], sport: 'golf', lat: 25.762, lng: -80.192),
      ];
      final rows = ProviderMatcher.retrieve(
        distSeed,
        QueryIntentParser.parse('golf coaches'),
        originLat: 25.7617,
        originLng: -80.1918,
      );
      final followUp = QueryIntentParser.parse('which of those is closest?');
      final resorted = ProviderMatcher.sort(rows, followUp.sortPreference);
      expect(resorted.first.name, 'Near');
    });
  });

  group('Intent routing (prompt 3)', () {
    test('policy question → question_about_booking', () {
      expect(
        QueryIntentParser.parse('how do refunds work').intentType,
        QueryIntentType.questionAboutBooking,
      );
    });
    test('out-of-scope ("what\'s the weather") → other', () {
      expect(
        QueryIntentParser.parse("what's the weather").intentType,
        QueryIntentType.other,
      );
    });
  });

  group('Discovery filters (prompt 4)', () {
    test('price + session-type filters honored together', () {
      final rows = ProviderMatcher.retrieve(
        _seed,
        const QueryIntent(
          intentType: QueryIntentType.findProviders,
          priceMaxCents: 6000,
          sessionType: 'one_on_one',
        ),
      );
      // ≤ \$60, 1-on-1, verified → Apex(\$60) + Ironside(\$45); Sunset(\$70) out.
      expect(rows.map((r) => r.name).toSet(), {'Apex', 'Ironside'});
    });

    test('dedupe by business keeps one (best-ranked) row per business', () {
      final dupSeed = [
        svc(id: 'x1', name: 'Apex', verified: true, price: 55, session: ['one_on_one', 'group'], sport: 'basketball'),
        svc(id: 'x2', name: 'Apex', verified: true, price: 45, session: ['group'], sport: 'soccer'),
        svc(id: 'x3', name: 'Downtown', verified: true, price: 35, session: ['group'], sport: 'basketball'),
      ];
      final rows = ProviderMatcher.retrieve(
        dupSeed,
        const QueryIntent(
          intentType: QueryIntentType.findProviders,
          sortPreference: SortPreference.cheapest,
        ),
      );
      // Same dedupe the discovery execute applies: one row per business name.
      final seen = <String>{};
      final deduped = [
        for (final m in rows)
          if (seen.add(m.name)) m,
      ];
      expect(deduped.map((m) => m.name), ['Downtown', 'Apex']);
      expect(
        deduped.firstWhere((m) => m.name == 'Apex').priceDollars,
        45,
        reason: 'cheapest Apex listing kept after sort',
      );
    });
  });

  group('Grounded demo proposals (mock generate-proposals)', () {
    test('keeps only verified, sport-matched, in-budget listings', () {
      final seed = [
        svc(id: 'p1', name: 'Apex', verified: true, price: 60, session: ['group'], sport: 'basketball', rating: 4.9, reviews: 40),
        svc(id: 'p2', name: 'OverBudget', verified: true, price: 200, session: ['group'], sport: 'basketball', rating: 4.8, reviews: 10),
        svc(id: 'p3', name: 'WrongSport', verified: true, price: 40, session: ['group'], sport: 'tennis', rating: 5.0, reviews: 5),
        svc(id: 'p4', name: 'Unverified', verified: false, price: 30, session: ['group'], sport: 'basketball', rating: 5.0, reviews: 99),
      ];
      final ranked = MockRepository.groundProposals(
        seed,
        sport: 'basketball',
        budgetPerSessionCents: 7500, // $75/session
      );
      final names =
          ranked.map((p) => (p['providerId'] as Map)['businessName']).toList();
      expect(names, ['Apex'],
          reason: 'OverBudget > \$75, WrongSport is tennis, Unverified is gated');
    });

    test('unverified is never proposed even when cheapest + top-rated', () {
      final seed = [
        svc(id: 'v', name: 'Verified', verified: true, price: 80, session: ['group'], sport: 'soccer', rating: 4.0, reviews: 10),
        svc(id: 'u', name: 'Unverified', verified: false, price: 20, session: ['group'], sport: 'soccer', rating: 5.0, reviews: 200),
      ];
      final ranked = MockRepository.groundProposals(seed, sport: 'soccer');
      expect(
        ranked.map((p) => (p['providerId'] as Map)['businessName']),
        ['Verified'],
      );
    });

    test('no eligible supply -> empty (honest no-supply, never padded)', () {
      final seed = [
        svc(id: 'x', name: 'Tennis', verified: true, price: 50, session: ['group'], sport: 'tennis'),
      ];
      expect(MockRepository.groundProposals(seed, sport: 'basketball'), isEmpty);
    });
  });

  group('Answer grounding (mock, deterministic)', () {
    const repo = MockRepository();

    test('empty rows → honest no-match + widening suggestion, no ids', () async {
      final a = await repo.answerChat(
        question: 'anything',
        rows: const [],
        intentType: QueryIntentType.findProviders,
      );
      expect(a['text'].toString().toLowerCase(), contains("couldn't find"));
      expect(a['provider_ids'], isEmpty);
    });

    test('facts in the answer come straight from the rows', () async {
      final rows = ProviderMatcher.retrieve(
        _seed,
        QueryIntentParser.parse('private lessons under \$75'),
      );
      final a = await repo.answerChat(
        question: 'list them',
        rows: rows,
        intentType: QueryIntentType.findProviders,
      );
      expect((a['provider_ids'] as List), isNotEmpty);
      expect(a['text'].toString(), contains('Apex'));
      expect(a['text'].toString(), contains('\$60'));
    });

    test('policy question is grounded in policies.md text only', () async {
      final a = await repo.answerChat(
        question: 'how do refunds work',
        rows: const [],
        intentType: QueryIntentType.questionAboutBooking,
        policyText: Policies.text,
      );
      expect(a['text'].toString(), contains('refund request'));
      expect(a['text'].toString(), contains('Stripe reports'));
      expect(a['text'].toString(), isNot(contains('automatically')));
      expect(a['provider_ids'], isEmpty);
    });

    test('out-of-scope answer steers back, no fabricated providers', () async {
      final a = await repo.answerChat(
        question: "what's the weather",
        rows: const [],
        intentType: QueryIntentType.other,
      );
      expect(a['provider_ids'], isEmpty);
      expect(a['text'].toString().toLowerCase(), contains('sporve'));
    });
  });
}
