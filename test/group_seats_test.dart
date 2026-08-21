// Verifies the GROUP-SEAT no-oversell contract on the mock (fake backend), the
// same invariant the DB function claim_group_seat enforces under a lock:
//   • a group service of capacity N accepts exactly N seats on one slot,
//   • the N+1th claim is REJECTED (returns null — honest failure, L-015),
//   • a same-athlete re-claim is idempotent (returns the SAME booking id, no
//     extra seat consumed),
//   • the coach mini-roster reflects exactly the claimed seats (L-005 shape:
//     first name + age band only).
//   flutter test test/group_seats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/data/mock_repository.dart';

void main() {
  // Static demo state is process-shared (const MockRepository is a stateless
  // wrapper, L-013); every test creates its OWN service id, so slot counts never
  // bleed across tests.
  const repo = MockRepository();

  Future<String> newGroupService({int capacity = 2}) async {
    final id = await repo.createService({
      'serviceType': 'group',
      'title': 'Saturday Small-Group Skills',
      'sport': 'Basketball',
      'durationMinutes': 60,
      'priceCents': 4000,
      'capacity': capacity,
    });
    expect(id, isNotNull);
    return id!;
  }

  test('group slot fills to capacity, then auto-closes (N+1 rejected)', () async {
    final svc = await newGroupService(capacity: 2);
    const date = '2026-08-01';
    const time = '10:00 AM';

    final a = await repo.claimGroupSeat(
        serviceId: svc, slotDate: date, slotTime: time, athleteId: 'a1');
    final b = await repo.claimGroupSeat(
        serviceId: svc, slotDate: date, slotTime: time, athleteId: 'a2');
    expect(a, isNotNull, reason: 'seat 1 of 2');
    expect(b, isNotNull, reason: 'seat 2 of 2');

    // Capacity reached: the third family is turned away, not oversold.
    final c = await repo.claimGroupSeat(
        serviceId: svc, slotDate: date, slotTime: time, athleteId: 'a3');
    expect(c, isNull, reason: 'slot FULL — no oversell');
  });

  test('same-athlete re-claim is idempotent (no second seat)', () async {
    final svc = await newGroupService(capacity: 2);
    const date = '2026-08-08';
    const time = '10:00 AM';

    final first = await repo.claimGroupSeat(
        serviceId: svc, slotDate: date, slotTime: time, athleteId: 'z1');
    final again = await repo.claimGroupSeat(
        serviceId: svc, slotDate: date, slotTime: time, athleteId: 'z1');
    expect(again, equals(first), reason: 'idempotent: same booking id');

    // One seat consumed, so a different athlete still fits.
    final other = await repo.claimGroupSeat(
        serviceId: svc, slotDate: date, slotTime: time, athleteId: 'z2');
    expect(other, isNotNull);
    // Now full.
    final third = await repo.claimGroupSeat(
        serviceId: svc, slotDate: date, slotTime: time, athleteId: 'z3');
    expect(third, isNull);
  });

  test('mini-roster reflects the claimed seats (first name + age band only)',
      () async {
    final svc = await newGroupService(capacity: 3);
    const date = '2026-08-15';
    const time = '09:00 AM';

    await repo.claimGroupSeat(
        serviceId: svc,
        slotDate: date,
        slotTime: time,
        athleteId: 'r1',
        athleteFirstName: 'Maya',
        athleteAgeBand: '9-11');
    await repo.claimGroupSeat(
        serviceId: svc,
        slotDate: date,
        slotTime: time,
        athleteId: 'r2',
        athleteFirstName: 'Theo',
        athleteAgeBand: '9-11');

    final roster = await repo.groupSlotRoster(
        serviceId: svc, slotDate: date, slotTime: time);
    expect(roster.length, 2);
    expect(roster.map((r) => r['athleteFirstName']).toSet(), {'Maya', 'Theo'});
    // COPPA shape (L-005): no DOB / contact fields leak into the roster row.
    expect(roster.first.containsKey('dateOfBirth'), isFalse);
    expect(roster.first.containsKey('athleteAgeBand'), isTrue);
  });

  test('recurring claim requires a service (honest null otherwise)', () async {
    final svc = await newGroupService();
    final ok = await repo.createRecurringClaim({
      'serviceId': svc,
      'dayOfWeek': 2,
      'startTime': '05:00 PM',
      'startDate': '2026-08-04',
      'cadence': 'weekly',
      'occurrenceCount': 8,
    });
    expect(ok, isNotNull);

    final bad = await repo.createRecurringClaim({
      'dayOfWeek': 2,
      'startTime': '05:00 PM',
      'startDate': '2026-08-04',
    });
    expect(bad, isNull, reason: 'no service -> no standing claim');
  });

  test('redeem with no credits returns null (no fake success)', () async {
    final svc = await newGroupService();
    final redeemed = await repo.redeemPackCredit(
        serviceId: svc, slotDate: '2026-08-22', slotTime: '11:00 AM');
    expect(redeemed, isNull, reason: 'no funded pack -> honest null (L-015)');
    expect(await repo.creditBalanceForService(svc), 0);
  });
}
