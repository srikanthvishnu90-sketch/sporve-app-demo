// Provider Model Rebuild — item #7 (deferred UI): the camp roster + tap
// check-in screen. Proves:
//   • a staffed coach sees the roster rows (first name/age band/emergency/
//     medical) and a tap check-in flips the row to "checked in" via the real
//     repo write (campCheckIn), never a locally-faked state.
//   • the SAME empty state renders whether nobody is registered yet OR the
//     caller isn't staff — the screen never distinguishes them (L-005/L-024:
//     a non-staff caller's campRoster() returns 0 rows by design, same as a
//     truly-empty camp).
//   flutter test test/camp_roster_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/core/data/mock_repository.dart';
import 'package:flutter_structure/presentation/provider/view/camp_roster_screen.dart';

/// Simulates the DB RLS/gate result for a non-staff caller: campRoster ALWAYS
/// returns zero rows, regardless of what's actually registered — exactly what
/// the real backend's `camp_staff_can_access` gate does (L-005/L-024).
class _NonStaffRepo extends MockRepository {
  const _NonStaffRepo();

  @override
  Future<List<Map<String, dynamic>>> campRoster({
    required String serviceId,
    required String day,
    bool asStaff = true,
  }) async =>
      const [];
}

void main() {
  const repo = MockRepository();

  Future<String> newCamp() async {
    final id = await repo.createService({
      'serviceType': 'camp',
      'title': 'Summer Skills Camp',
      'sport': 'Soccer',
      'durationMinutes': 360,
      'priceCents': 30000,
      'capacity': 10,
      'ageBand': '9-11',
      'startsOn': '2026-07-06',
      'endsOn': '2026-07-10',
      'dailyStartTime': '09:00:00',
      'dailyEndTime': '15:00:00',
    });
    expect(id, isNotNull);
    return id!;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    AppRepository r,
    String serviceId,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AppRepository>.value(value: r)],
        child: MaterialApp(
          home: CampRosterScreen(serviceId: serviceId, campTitle: 'Summer Skills Camp'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('staff roster renders PII rows and tap check-in flips state',
      (tester) async {
    final camp = await newCamp();
    await repo.registerCampAthlete(
      serviceId: camp,
      athleteId: 'cr-1',
      athleteFirstName: 'Maya',
      athleteAgeBand: '9-11',
      emergencyContact: {'name': 'Parent One', 'phone': '555-0100', 'relation': 'Mother'},
      medicalNotes: 'Peanut allergy — EpiPen in bag',
    );

    await pumpScreen(tester, repo, camp);

    // Roster row renders the camper + the sensitive fields, staff-eyes-only.
    expect(find.text('Maya'), findsOneWidget);
    expect(find.textContaining('Peanut allergy'), findsOneWidget);
    expect(find.textContaining('Parent One'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('NOT IN'), findsOneWidget);

    // Tap check-in — a REAL repo write (campCheckIn), not a local fake state.
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();

    expect(find.text('Checked in — tap to refresh'), findsOneWidget);
    expect(find.text('NOT IN'), findsNothing);
  });

  testWidgets('empty roster (nobody registered) shows the honest empty state',
      (tester) async {
    final camp = await newCamp(); // nobody registered
    await pumpScreen(tester, repo, camp);

    expect(find.text('No campers to show'), findsOneWidget);
  });

  testWidgets('non-staff caller sees the SAME empty state — never a PII leak',
      (tester) async {
    const nonStaffRepo = _NonStaffRepo();
    // Register through the REAL repo so PII genuinely exists for this camp —
    // the non-staff view must still show nothing.
    final camp = await nonStaffRepo.createService({
      'serviceType': 'camp',
      'title': 'Summer Skills Camp',
      'durationMinutes': 360,
      'priceCents': 30000,
      'capacity': 10,
      'startsOn': '2026-07-06',
      'endsOn': '2026-07-10',
    });
    await nonStaffRepo.registerCampAthlete(
      serviceId: camp!,
      athleteId: 'cr-2',
      athleteFirstName: 'Ben',
      emergencyContact: {'name': 'Parent Two', 'phone': '555-0199'},
      medicalNotes: 'Asthma',
    );

    await pumpScreen(tester, nonStaffRepo, camp);

    expect(find.text('No campers to show'), findsOneWidget);
    expect(find.text('Ben'), findsNothing);
    expect(find.textContaining('Asthma'), findsNothing);
    expect(find.textContaining('Parent Two'), findsNothing);
  });
}
