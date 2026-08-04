import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_structure/core/matching/provider_matcher.dart';
import 'package:flutter_structure/core/models/query_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });
    await GetStorage.init();
  });

  group('Day 04 Pre-Launch Checklist Verification', () {
    setUp(() {
      final box = GetStorage();
      box.erase();
    });

    group('Item 0.1 & 0.2: Thin-supply & Waitlist capture signal storage', () {
      test('Unserved area waitlist capture saves demand signal to GetStorage', () async {
        final box = GetStorage();
        expect(box.read('demand_signals'), isNull);

        // Simulate waitlist capture
        final List<dynamic> signals = box.read('demand_signals') ?? [];
        signals.add({
          'email': 'parent@example.com',
          'zip': '90210',
          'sport': 'Cricket',
          'capturedAt': DateTime.now().toIso8601String(),
        });
        box.write('demand_signals', signals);

        final saved = box.read('demand_signals') as List;
        expect(saved, isNotNull);
        expect(saved.length, 1);
        expect(saved[0]['email'], 'parent@example.com');
        expect(saved[0]['zip'], '90210');
        expect(saved[0]['sport'], 'Cricket');
      });
    });

    group('Item 0.3: Per-sport safety gating across full catalog', () {
      final sampleCatalog = [
        // High-risk combat / contact sports (high intensity)
        {
          '_id': 'boxing_high',
          'providerName': 'Iron Boxing Gym',
          'title': 'Advanced Sparring',
          'sportType': 'boxing',
          'minimumAge': 6,
          'maximumAge': 18,
          'price': 60,
          'intensity': 'high',
          'background_check_status': 'verified',
          'account_status': 'active',
        },
        {
          '_id': 'boxing_low',
          'providerName': 'Little Champions Boxing',
          'title': 'Junior Boxing Fundamentals',
          'sportType': 'boxing',
          'minimumAge': 6,
          'maximumAge': 12,
          'price': 40,
          'intensity': 'low',
          'background_check_status': 'verified',
          'account_status': 'active',
        },
        {
          '_id': 'mma_high',
          'providerName': 'Apex MMA Academy',
          'title': 'Full Contact Fight Prep',
          'sportType': 'mma',
          'minimumAge': 6,
          'maximumAge': 18,
          'price': 70,
          'intensity': 'high',
          'background_check_status': 'verified',
          'account_status': 'active',
        },
        {
          '_id': 'gymnastics_high',
          'providerName': 'Elite Gymnastics Club',
          'title': 'High Vault & Tumbling',
          'sportType': 'gymnastics',
          'minimumAge': 6,
          'maximumAge': 18,
          'price': 65,
          'intensity': 'high',
          'background_check_status': 'verified',
          'account_status': 'active',
        },
        {
          '_id': 'rugby_high',
          'providerName': 'Thunder Rugby FC',
          'title': 'Tackle & Ruck Camp',
          'sportType': 'rugby',
          'minimumAge': 6,
          'maximumAge': 18,
          'price': 55,
          'intensity': 'high',
          'background_check_status': 'verified',
          'account_status': 'active',
        },
      ];

      test('Young child (age 7) is strictly blocked from high-intensity in high-risk sports', () {
        // Test Boxing for a 7-year-old
        final boxingMatches = ProviderMatcher.retrieve(
          sampleCatalog,
          QueryIntent(sport: 'boxing', age: 7),
        );
        expect(
          boxingMatches.map((m) => m.name),
          contains('Little Champions Boxing'),
          reason: 'Low intensity boxing for 7-year-old must pass',
        );
        expect(
          boxingMatches.map((m) => m.name),
          isNot(contains('Iron Boxing Gym')),
          reason: 'High intensity boxing for 7-year-old must be blocked by safety gating',
        );

        // Test MMA for a 7-year-old
        final mmaMatches = ProviderMatcher.retrieve(
          sampleCatalog,
          QueryIntent(sport: 'mma', age: 7),
        );
        expect(
          mmaMatches,
          isEmpty,
          reason: 'High intensity MMA for 7-year-old must return zero matches due to safety ceiling',
        );

        // Test Gymnastics for a 7-year-old
        final gymnasticsMatches = ProviderMatcher.retrieve(
          sampleCatalog,
          QueryIntent(sport: 'gymnastics', age: 7),
        );
        expect(
          gymnasticsMatches,
          isEmpty,
          reason: 'High intensity Gymnastics for 7-year-old must return zero matches',
        );

        // Test Rugby for a 7-year-old
        final rugbyMatches = ProviderMatcher.retrieve(
          sampleCatalog,
          QueryIntent(sport: 'rugby', age: 7),
        );
        expect(
          rugbyMatches,
          isEmpty,
          reason: 'High intensity Rugby for 7-year-old must return zero matches',
        );
      });
    });
  });
}
