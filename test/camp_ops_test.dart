// Verifies the CAMP ops layer on the mock (fake backend) — the same invariants the
// DB enforces (20260729_000700_camps.sql + 20260729_000701_camp_roster.sql):
//   • a camp is a SERVICE with capacity; registration RIDES the group-seat rails,
//     so capacity auto-close is INHERITED — the (N+1)th registration is rejected
//     (returns null — honest failure, L-015), exactly like a group slot.
//   • the roster carries emergency + allergy/medical PII, readable ONLY by staff
//     (L-005): the non-staff view returns NOTHING (mirrors the DB RLS 0-row result).
//   • tap check-in sets one state per roster entry per day (a re-tap refreshes it).
//   • camp_price_due math: early-bird + deposit → due-now/balance, cents-exact.
//   flutter test test/camp_ops_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/data/mock_repository.dart';

void main() {
  const repo = MockRepository();

  Future<String> newCamp({
    int capacity = 2,
    int priceCents = 30000,
    int? earlyBirdPriceCents,
    String? earlyBirdCutoff,
    int? depositCents,
    String startsOn = '2026-07-06',
  }) async {
    final id = await repo.createService({
      'serviceType': 'camp',
      'title': 'Summer Skills Camp',
      'sport': 'Soccer',
      'durationMinutes': 360,
      'priceCents': priceCents,
      'capacity': capacity,
      'ageBand': '9-11',
      'startsOn': startsOn,
      'endsOn': '2026-07-10',
      'dailyStartTime': '09:00:00',
      'dailyEndTime': '15:00:00',
      'earlyBirdPriceCents': earlyBirdPriceCents,
      'earlyBirdCutoff': earlyBirdCutoff,
      'depositCents': depositCents,
    });
    expect(id, isNotNull);
    return id!;
  }

  test('camp registration inherits group-seat capacity auto-close (N+1 rejected)',
      () async {
    final camp = await newCamp(capacity: 2);

    final a = await repo.registerCampAthlete(
        serviceId: camp, athleteId: 'c1', athleteFirstName: 'Ava', athleteAgeBand: '9-11');
    final b = await repo.registerCampAthlete(
        serviceId: camp, athleteId: 'c2', athleteFirstName: 'Ben', athleteAgeBand: '9-11');
    expect(a, isNotNull, reason: 'seat 1 of 2');
    expect(b, isNotNull, reason: 'seat 2 of 2');

    // Capacity reached: the third registration is turned away — the SAME no-oversell
    // lock the group service uses, not a new registration codepath.
    final c = await repo.registerCampAthlete(
        serviceId: camp, athleteId: 'c3', athleteFirstName: 'Cy', athleteAgeBand: '9-11');
    expect(c, isNull, reason: 'camp FULL — no oversell');
  });

  test('same-athlete re-registration is idempotent (one seat, one roster row)',
      () async {
    final camp = await newCamp(capacity: 3);
    final first = await repo.registerCampAthlete(
        serviceId: camp, athleteId: 'r1', athleteFirstName: 'Nia');
    final again = await repo.registerCampAthlete(
        serviceId: camp, athleteId: 'r1', athleteFirstName: 'Nia');
    expect(again, equals(first), reason: 'idempotent: same booking id');

    final roster = await repo.campRoster(serviceId: camp, day: '2026-07-06');
    expect(roster.length, 1, reason: 'no duplicate roster row on re-tap');
  });

  test('roster emergency + medical PII is STAFF-ONLY (L-005)', () async {
    final camp = await newCamp(capacity: 4);
    await repo.registerCampAthlete(
      serviceId: camp,
      athleteId: 'p1',
      athleteFirstName: 'Maya',
      athleteAgeBand: '9-11',
      emergencyContact: {'name': 'Parent One', 'phone': '555-0100'},
      medicalNotes: 'Peanut allergy — EpiPen in bag',
    );

    // Assigned staff: the sensitive fields ARE present.
    final staffView = await repo.campRoster(serviceId: camp, day: '2026-07-06');
    expect(staffView.length, 1);
    final row = staffView.first;
    expect(row['medicalNotes'], contains('Peanut'));
    expect((row['emergencyContact'] as Map)['phone'], '555-0100');
    expect(row['athleteFirstName'], 'Maya');

    // NON-staff (a parent / another org): the roster returns NOTHING — the same
    // 0-row result the DB RLS gives, never a PII-stripped leak.
    final nonStaff =
        await repo.campRoster(serviceId: camp, day: '2026-07-06', asStaff: false);
    expect(nonStaff, isEmpty, reason: 'minors PII never leaves assigned staff');
  });

  test('tap check-in sets one state per roster entry per day (re-tap refreshes)',
      () async {
    final camp = await newCamp(capacity: 2);
    await repo.registerCampAthlete(
        serviceId: camp, athleteId: 'k1', athleteFirstName: 'Rio');
    final roster = await repo.campRoster(serviceId: camp, day: '2026-07-06');
    final rosterId = roster.first['rosterId'] as String;

    // Before check-in: not present today.
    expect(roster.first['checkedInAt'], isNull);

    final at = await repo.campCheckIn(rosterId: rosterId, day: '2026-07-06');
    expect(at, isNotNull);

    final afterCheckIn = await repo.campRoster(serviceId: camp, day: '2026-07-06');
    expect(afterCheckIn.first['checkedInAt'], isNotNull);

    // A DIFFERENT day is still un-checked (state is per day).
    final otherDay = await repo.campRoster(serviceId: camp, day: '2026-07-07');
    expect(otherDay.first['checkedInAt'], isNull);

    // Re-tap the same day is idempotent (still one state; refreshed, not doubled).
    final again = await repo.campCheckIn(rosterId: rosterId, day: '2026-07-06');
    expect(again, isNotNull);
  });

  test('camp_price_due: early-bird + deposit math is cents-exact', () async {
    // Full $300, early-bird $250 (cutoff 2026-06-01), deposit $100.
    final camp = await newCamp(
      priceCents: 30000,
      earlyBirdPriceCents: 25000,
      earlyBirdCutoff: '2026-06-01',
      depositCents: 10000,
    );

    // Before the cutoff: early-bird full price, deposit due now, balance = rest.
    final early = await repo.campPriceDue(serviceId: camp, asOf: '2026-05-15');
    expect(early!['fullPriceCents'], 25000);
    expect(early['dueNowCents'], 10000);
    expect(early['balanceCents'], 15000);
    expect(early['isEarlyBird'], true);
    expect(early['hasDeposit'], true);

    // After the cutoff: full price, same deposit, larger balance.
    final late = await repo.campPriceDue(serviceId: camp, asOf: '2026-06-15');
    expect(late!['fullPriceCents'], 30000);
    expect(late['dueNowCents'], 10000);
    expect(late['balanceCents'], 20000);
    expect(late['isEarlyBird'], false);
  });

  test('camp_price_due: no deposit → pay in full, zero balance', () async {
    final camp = await newCamp(priceCents: 20000);
    final due = await repo.campPriceDue(serviceId: camp, asOf: '2026-07-01');
    expect(due!['dueNowCents'], 20000);
    expect(due['balanceCents'], 0);
    expect(due['hasDeposit'], false);
  });
}
