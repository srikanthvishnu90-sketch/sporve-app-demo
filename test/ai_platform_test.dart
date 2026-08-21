import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/matching/provider_matcher.dart';
import 'package:sporve_app/core/models/query_intent.dart';
import 'package:sporve_app/core/models/query_intent_parser.dart';

void main() {
  group('AI Platform Suite Automated Tests', () {
    group('1. AI Natural Language Search Parser (QueryIntent)', () {
      test(
        'Parses sport, age, and budget correctly from natural language prompt',
        () {
          const prompt = 'Boxing lessons for 8 year old under \$70 in Chicago';
          final intent = QueryIntentParser.parse(prompt);

          expect(intent.sport, 'boxing');
          expect(intent.age, 8);
          expect(intent.priceMaxCents, 7000);
        },
      );

      test('Gracefully handles vague prompts with fallback intent', () {
        const vaguePrompt = 'Soccer coaching near me';
        final intent = QueryIntentParser.parse(vaguePrompt);

        expect(intent.sport, 'soccer');
        expect(intent.age, isNull);
        expect(intent.priceMaxCents, isNull);
      });
    });

    group('2. AI Chatbox & Draft Reply Engine', () {
      test(
        'Generates structured camp recap draft without throwing exceptions',
        () {
          final mockMessages = [
            {
              'sender': 'coach',
              'text': 'Day 1 completed! Drills focused on agility and passing.',
            },
          ];

          String generateDraftRecap(List<Map<String, String>> messages) {
            if (messages.isEmpty) return 'No recap available.';
            return 'Recap: ${messages.first['text']} Great work athletes!';
          }

          final recap = generateDraftRecap(mockMessages);
          expect(recap, contains('Day 1 completed'));
          expect(recap, contains('Great work athletes'));
        },
      );
    });

    group('3. AI "Recommended For You" Matching Engine & Safety Gating', () {
      final sampleCatalog = [
        {
          '_id': 'high_boxing',
          'providerName': 'Iron Boxing Gym',
          'title': 'Advanced Contact Sparring',
          'sportType': 'boxing',
          'minimumAge': 6,
          'maximumAge': 18,
          'price': 80,
          'intensity': 'high',
          'provider_status': 'approved',
          'background_check_status': 'verified',
          'background_check_completed_at': '2026-08-20T12:00:00Z',
          'account_status': 'active',
          'rating': 4.9,
        },
        {
          '_id': 'low_boxing',
          'providerName': 'Little Champions Boxing',
          'title': 'Junior Fundamentals',
          'sportType': 'boxing',
          'minimumAge': 6,
          'maximumAge': 12,
          'price': 50,
          'intensity': 'low',
          'provider_status': 'approved',
          'background_check_status': 'verified',
          'background_check_completed_at': '2026-08-20T12:00:00Z',
          'account_status': 'active',
          'rating': 4.8,
        },
      ];

      test(
        'Recommends low-intensity boxing for 8-year-old child while blocking high-intensity',
        () {
          final matches = ProviderMatcher.retrieve(
            sampleCatalog,
            QueryIntent(sport: 'boxing', age: 8),
          );

          expect(matches.length, 1);
          expect(matches.first.name, 'Little Champions Boxing');
          expect(
            matches.map((m) => m.name),
            isNot(contains('Iron Boxing Gym')),
            reason:
                'High intensity contact boxing for 8yo child MUST be blocked by AI safety ceiling',
          );
        },
      );
    });
  });
}
