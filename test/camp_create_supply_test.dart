// Provider Model Rebuild — item #7 (deferred UI, camp CREATE fields): proves
// SupplyController.addService's camp facets (date range, daily hours, age
// band, early-bird + deposit) actually reach `createService` and land where
// `campPriceDue` reads them — the create-sheet fields are not decorative.
//   flutter test test/camp_create_supply_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/mock_repository.dart';
import 'package:flutter_structure/presentation/provider/controllers/supply_controller.dart';

void main() {
  test('addService passes camp facets through; campPriceDue reflects them',
      () async {
    const repo = MockRepository();
    final c = SupplyController(repo);

    final ok = await c.addService(
      serviceType: 'camp',
      title: 'Fall Skills Camp',
      sport: 'Basketball',
      durationMinutes: 360,
      priceCents: 30000, // $300 full price
      capacity: 12,
      startsOn: '2026-09-07',
      endsOn: '2026-09-11',
      dailyStartTime: '09:00:00',
      dailyEndTime: '15:00:00',
      ageBand: '9-11',
      earlyBirdPriceCents: 25000, // $250
      earlyBirdCutoff: '2026-08-01',
      depositCents: 10000, // $100
    );
    expect(ok, isTrue);

    final svc = c.services.firstWhere((s) => s['title'] == 'Fall Skills Camp');
    final id = svc['_id'].toString();
    expect(svc['ageBand'], '9-11');
    expect(svc['startsOn'], '2026-09-07');
    expect(svc['dailyStartTime'], '09:00:00');

    // Before the early-bird cutoff: reduced price, deposit due now, balance
    // for the rest.
    final early = await repo.campPriceDue(serviceId: id, asOf: '2026-07-15');
    expect(early!['fullPriceCents'], 25000);
    expect(early['dueNowCents'], 10000);
    expect(early['balanceCents'], 15000);
    expect(early['isEarlyBird'], true);

    // After the cutoff: full price applies.
    final late = await repo.campPriceDue(serviceId: id, asOf: '2026-09-01');
    expect(late!['fullPriceCents'], 30000);
    expect(late['isEarlyBird'], false);
  });

  test('a non-camp service never carries camp facets', () async {
    const repo = MockRepository();
    final c = SupplyController(repo);
    final ok = await c.addService(
      serviceType: 'private',
      title: 'Private lesson',
      durationMinutes: 60,
      priceCents: 8000,
      // Camp-only args are simply not passed for a non-camp type; addService
      // itself only forwards them when serviceType == 'camp'.
    );
    expect(ok, isTrue);
    final svc = c.services.firstWhere((s) => s['title'] == 'Private lesson');
    final id = svc['_id'].toString();
    // campPriceDue refuses a non-camp service (null — honest failure, L-015).
    expect(await repo.campPriceDue(serviceId: id, asOf: '2026-07-15'), isNull);
  });
}
