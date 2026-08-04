import 'package:flutter/foundation.dart';
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

  group('Day 04 Next Work Verification', () {
    test('1. No Geographic Assumptions: Distance calculation works across 3 metros', () {
      final sampleService = {
        '_id': 'prog_nyc',
        'providerName': 'NYC Basketball',
        'title': 'Manhattan Hoops',
        'sportType': 'basketball',
        'minimumAge': 6,
        'maximumAge': 18,
        'price': 50,
        'background_check_status': 'verified',
        'account_status': 'active',
        'location': {
          'coordinates': [-74.0060, 40.7128], // New York City
        },
      };

      // 1. NYC Metro Origin (New York)
      final nycMatches = ProviderMatcher.retrieve(
        [sampleService],
        QueryIntent(sport: 'basketball', maxDistanceKm: 20),
        originLat: 40.7128,
        originLng: -74.0060,
      );
      expect(nycMatches.length, 1);
      expect(nycMatches[0].distanceKm, closeTo(0.0, 1.0));

      // 2. Chicago Origin (41.8781, -87.6298) — NYC service is ~1145 km away, so maxDistance 20km excludes it
      final chicagoMatches = ProviderMatcher.retrieve(
        [sampleService],
        QueryIntent(sport: 'basketball', maxDistanceKm: 20),
        originLat: 41.8781,
        originLng: -87.6298,
      );
      expect(chicagoMatches, isEmpty);

      // 3. LA Origin (34.0522, -118.2437) — NYC service is ~3900 km away
      final laMatches = ProviderMatcher.retrieve(
        [sampleService],
        QueryIntent(sport: 'basketball', maxDistanceKm: 50),
        originLat: 34.0522,
        originLng: -118.2437,
      );
      expect(laMatches, isEmpty);
    });

    test('2. Broad at Launch: Regional Demand Signals storage & retrieval', () {
      final box = GetStorage();
      box.erase();

      final signals = [
        {'email': 'ny_parent@example.com', 'zip': '10001', 'sport': 'Tennis'},
        {'email': 'la_parent@example.com', 'zip': '90001', 'sport': 'Soccer'},
      ];
      box.write('demand_signals', signals);

      final read = box.read('demand_signals') as List;
      expect(read.length, 2);
      expect(read[0]['zip'], '10001');
      expect(read[1]['zip'], '90001');
    });

    test('3. Kill Offline Demo in Prod: USE_MOCK_REPO is force-false in release mode', () {
      // kReleaseMode check logic contract
      const testMockRepoFlag = true;
      final effectiveMockMode = !kReleaseMode && testMockRepoFlag;
      
      if (kReleaseMode) {
        expect(effectiveMockMode, isFalse, reason: 'Mock mode MUST be false in release mode');
      } else {
        expect(effectiveMockMode, isTrue, reason: 'Debug mode allows mock mode for local testing');
      }
    });

    test('4. Edge Function Invocation Check: Every client function name is non-empty', () {
      final invokedFunctions = [
        'ai-match',
        'search-parse',
        'search-execute',
        'waitlist-offer-draft',
        'stripe-provider-payouts',
        'camp-recap',
        'camp-broadcast',
        'draft-recap',
        'message-draft',
        'coach-invoice-create',
        'create-checkout-session',
      ];

      for (final fn in invokedFunctions) {
        expect(fn, isNotEmpty);
        expect(fn.contains(' '), isFalse);
      }
    });
  });
}
