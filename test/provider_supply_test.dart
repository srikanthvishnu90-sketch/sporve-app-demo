// Provider Model Rebuild — Part 0 / item #1. Proves the model's core promise on
// the deterministic MockRepository (offline, no network):
//   • A SERVICE carries NO times — createService has no time args (compile-time),
//     and two services read the ONE shared weekly availability.
//   • Editing Tuesday ONCE updates EVERY service's bookable inventory, with no
//     per-service edit ("coach changes Tuesday hours once → every service updates").
//   • Whole-day exceptions and vacation subtract from the multiplication.
//   flutter test test/provider_supply_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/core/data/mock_repository.dart';

void main() {
  const AppRepository repo = MockRepository();

  // A fixed two-week window containing exactly two Tuesdays (Aug 4 + Aug 11 2026).
  const from = '2026-08-03'; // Monday
  const to = '2026-08-16'; // Sunday

  int tuesdaySlotCount(List<Map<String, dynamic>> slots) =>
      slots.where((s) => s['date'] == '2026-08-04' || s['date'] == '2026-08-11').length;

  test('one weekly grid feeds every service; one Tuesday edit updates all', () async {
    // 1) Set the ONE weekly availability: Tuesday 15:00–17:00 (a 2h block).
    var ok = await repo.setWeeklyAvailability([
      {'dayOfWeek': 2, 'startTime': '15:00', 'endTime': '17:00'},
    ]);
    expect(ok, isTrue);

    // 2) Create TWO services — NEITHER asks for a time (no time args exist).
    final svcA = await repo.createService({
      'serviceType': 'private',
      'title': '60-min private',
      'sport': 'Basketball',
      'durationMinutes': 60,
      'priceCents': 8000,
      'capacity': 1,
    });
    final svcB = await repo.createService({
      'serviceType': 'group',
      'title': 'Small-group clinic',
      'sport': 'Basketball',
      'durationMinutes': 60,
      'priceCents': 4000,
      'capacity': 4,
    });
    expect(svcA, isNotNull);
    expect(svcB, isNotNull);

    // 3) Both services multiply against the SAME grid: 2 slots (15:00, 16:00)
    //    per Tuesday × 2 Tuesdays = 4 each.
    final aSlots = await repo.bookableSlots(
        providerId: 'mock-provider', serviceId: svcA!, fromDate: from, toDate: to);
    final bSlots = await repo.bookableSlots(
        providerId: 'mock-provider', serviceId: svcB!, fromDate: from, toDate: to);
    expect(tuesdaySlotCount(aSlots), 4);
    expect(tuesdaySlotCount(bSlots), 4);

    // Shared calendar proof: identical date+time slots for both services.
    String key(Map<String, dynamic> s) => '${s['date']} ${s['startTime']}';
    expect(aSlots.map(key).toSet(), bSlots.map(key).toSet());

    // The group service exposes its full capacity per slot; private exposes 1.
    expect(aSlots.first['seatsRemaining'], 1);
    expect(bSlots.first['seatsRemaining'], 4);

    // 4) THE CHECK: extend Tuesday to 15:00–19:00 ONCE. No service is touched.
    ok = await repo.setWeeklyAvailability([
      {'dayOfWeek': 2, 'startTime': '15:00', 'endTime': '19:00'},
    ]);
    expect(ok, isTrue);

    final aAfter = await repo.bookableSlots(
        providerId: 'mock-provider', serviceId: svcA, fromDate: from, toDate: to);
    final bAfter = await repo.bookableSlots(
        providerId: 'mock-provider', serviceId: svcB, fromDate: from, toDate: to);
    // 4 slots (15,16,17,18) per Tuesday × 2 = 8 — for BOTH services, from one edit.
    expect(tuesdaySlotCount(aAfter), 8);
    expect(tuesdaySlotCount(bAfter), 8);
  });

  test('exceptions and vacation subtract from the multiplication', () async {
    await repo.setWeeklyAvailability([
      {'dayOfWeek': 2, 'startTime': '15:00', 'endTime': '17:00'},
    ]);
    final svc = await repo.createService({
      'serviceType': 'private',
      'title': 'Lesson',
      'durationMinutes': 60,
      'priceCents': 8000,
      'capacity': 1,
    });

    // Skip the first Tuesday (Aug 4) → only Aug 11 remains (2 slots).
    expect(await repo.addAvailabilityException('2026-08-04'), isTrue);
    var slots = await repo.bookableSlots(
        providerId: 'mock-provider', serviceId: svc!, fromDate: from, toDate: to);
    expect(slots.any((s) => s['date'] == '2026-08-04'), isFalse);
    expect(slots.any((s) => s['date'] == '2026-08-11'), isTrue);

    // Vacation through Aug 12 → both Tuesdays (Aug 4 skipped, Aug 11 on/before
    // vacation) are gone; window yields zero.
    await repo.removeAvailabilityException('2026-08-04');
    expect(await repo.setAvailabilitySettings(vacationUntil: '2026-08-12'), isTrue);
    slots = await repo.bookableSlots(
        providerId: 'mock-provider', serviceId: svc, fromDate: from, toDate: to);
    expect(tuesdaySlotCount(slots), 0);

    // Clear vacation so process-shared static state doesn't leak to other tests.
    await repo.setAvailabilitySettings(vacationUntil: null);
  });
}
