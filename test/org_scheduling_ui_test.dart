// Provider Model Rebuild — item #6 (deferred UI): org scheduling surfaces.
// Proves:
//   • the trainers × venues grid renders one card per occupied cell, grouped
//     by venue, and visually FLAGS a venue conflict (the `hasConflict` field
//     org_schedule_grid/the mock compute, 20260729_000600) with a CONFLICT
//     badge — a pure rendering check (the guard itself already prevents a
//     real conflicting write; see 20260729_000600's own VERIFY block).
//   • the org-service staffing sheet's "any available trainer" indicator
//     mirrors service_allows_any_available (20260729_000610): ENABLED
//     (interactive) for a group/camp service, DISABLED (locked, onChanged
//     null) for a private service — never a setting the coach can override.
//   flutter test test/org_scheduling_ui_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/core/data/mock_repository.dart';
import 'package:flutter_structure/presentation/provider/view/provider_org_grid_screen.dart';
import 'package:flutter_structure/presentation/provider/widgets/org_service_staffing_sheet.dart';

/// The venue-conflict guard (enforce_booking_venue_conflict) makes a REAL
/// conflicting write impossible to persist — so to prove the GRID's own
/// rendering (not the guard, which is proven at the DB/mock booking layer
/// elsewhere), this stub returns a canned grid exactly like org_schedule_grid
/// would for a legacy/pre-guard row: two trainers on two venues, one flagged.
class _CannedGridRepo extends MockRepository {
  const _CannedGridRepo();

  @override
  Future<List<Map<String, dynamic>>> orgScheduleGrid({
    required String fromDate,
    required String toDate,
  }) async => [
        {
          'date': '2026-08-04',
          'slotTime': '17:00:00',
          'locationId': 'loc-1',
          'locationName': 'Court 1',
          'serviceId': 'svc-a',
          'serviceTitle': 'Elite Group Training',
          'assignedMemberId': 'mem-a',
          'trainerName': 'Dana Coach',
          'booked': 4,
          'capacity': 8,
          'hasConflict': true,
        },
        {
          'date': '2026-08-04',
          'slotTime': '17:00:00',
          'locationId': 'loc-1',
          'locationName': 'Court 1',
          'serviceId': 'svc-b',
          'serviceTitle': 'Private Lesson',
          'assignedMemberId': 'mem-b',
          'trainerName': 'Sam Coach',
          'booked': 1,
          'capacity': 1,
          'hasConflict': true,
        },
        {
          'date': '2026-08-05',
          'slotTime': '09:00:00',
          'locationId': 'loc-2',
          'locationName': 'Field A',
          'serviceId': 'svc-c',
          'serviceTitle': 'Camp Day',
          'assignedMemberId': null,
          'trainerName': 'Any available',
          'booked': 6,
          'capacity': 12,
          'hasConflict': false,
        },
      ];
}

void main() {
  testWidgets('org grid renders trainers × venues and flags the conflict',
      (tester) async {
    const repo = _CannedGridRepo();
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AppRepository>.value(value: repo)],
        child: const MaterialApp(home: ProviderOrgGridScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Venue grouping.
    expect(find.text('COURT 1'), findsOneWidget);
    expect(find.text('FIELD A'), findsOneWidget);

    // Trainer × service cells.
    expect(find.text('Elite Group Training'), findsOneWidget);
    expect(find.textContaining('Dana Coach'), findsOneWidget);
    expect(find.text('Private Lesson'), findsOneWidget);
    expect(find.textContaining('Sam Coach'), findsOneWidget);
    expect(find.text('Camp Day'), findsOneWidget);
    expect(find.textContaining('Any available'), findsOneWidget);

    // The two Court-1 rows at the same slot are flagged; Field A is not.
    expect(find.text('CONFLICT'), findsNWidgets(2));

    // Top banner surfaces the conflict too.
    expect(find.textContaining('double-booked'), findsOneWidget);
  });

  testWidgets('org grid: no rows renders the honest empty state', (tester) async {
    const repo = MockRepository(); // fresh — no bookings/venues seeded
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AppRepository>.value(value: repo)],
        child: const MaterialApp(home: ProviderOrgGridScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing on the grid this week'), findsOneWidget);
    expect(find.text('CONFLICT'), findsNothing);
  });

  testWidgets(
      'org-service staffing: any-available is enabled for group, locked off for private',
      (tester) async {
    const repo = MockRepository();
    final privateId = await repo.createService({
      'serviceType': 'private',
      'title': 'Private Lesson',
      'sport': 'Tennis',
      'priceCents': 8000,
      'capacity': 1,
    });
    final groupId = await repo.createService({
      'serviceType': 'group',
      'title': 'Group Class',
      'sport': 'Tennis',
      'priceCents': 4000,
      'capacity': 8,
    });
    expect(privateId, isNotNull);
    expect(groupId, isNotNull);

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AppRepository>.value(value: repo)],
        child: const MaterialApp(
          home: Scaffold(body: OrgServiceStaffingSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Newest-created (group) service is selected by default (getMyServices
    // sorts active-first, newest-first) — any-available is ALLOWED + the
    // locked indicator switch is INTERACTIVE (onChanged non-null).
    expect(find.textContaining('Allowed automatically'), findsOneWidget);
    Switch anyAvailableSwitch =
        tester.widgetList<Switch>(find.byType(Switch)).last;
    expect(anyAvailableSwitch.onChanged, isNotNull);

    // Switch the dropdown selection to the PRIVATE service.
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private Lesson (private)').last);
    await tester.pumpAndSettle();

    // Now any-available is NOT allowed — DISABLED (locked, onChanged null),
    // mirroring service_allows_any_available for a private service.
    expect(find.textContaining('Not allowed'), findsOneWidget);
    anyAvailableSwitch = tester.widgetList<Switch>(find.byType(Switch)).last;
    expect(anyAvailableSwitch.onChanged, isNull);
  });
}
