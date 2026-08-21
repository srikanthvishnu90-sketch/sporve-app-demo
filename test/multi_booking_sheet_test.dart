// Provider Model Rebuild — item #2 (family side, docs/PROVIDER-UI-FOLLOWUPS.md
// #1): proves the multi-booking sheet's GROUP SEAT path (a) shows a live
// seats-left count sourced from the roster (never a stale capacity number),
// and (b) BLOCKS a claim once the slot is full — an honest failure (L-015),
// not a silent no-op.
//   flutter test test/multi_booking_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sporve_app/core/data/app_repository.dart';
import 'package:sporve_app/presentation/client/controllers/home_controller.dart';
import 'package:sporve_app/presentation/client/widgets/multi_booking_sheet.dart';

/// A one-seat group service. Starts empty; the mock enforces no-oversell the
/// same way [MockRepository] does — a claim past capacity returns null.
class _FakeGroupRepo implements AppRepository {
  final List<Map<String, dynamic>> _bookings = [];
  String? claimError;
  static const _capacity = 1;

  @override
  Future<List<Map<String, dynamic>>> bookableSlots({
    required String providerId,
    required String serviceId,
    required String fromDate,
    required String toDate,
  }) async => [
    {
      'date': fromDate,
      'startTime': '05:00 PM',
      'endTime': '06:00 PM',
      'capacity': _capacity,
      'booked': _bookings.length,
      'seatsRemaining': _capacity - _bookings.length,
      'locationId': null,
      'locationName': null,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> groupSlotRoster({
    required String serviceId,
    required String slotDate,
    required String slotTime,
  }) async => _bookings
      .map(
        (b) => <String, dynamic>{
          'bookingId': b['id'],
          'athleteFirstName': b['athleteFirstName'],
          'athleteAgeBand': b['athleteAgeBand'],
          'status': 'pending',
          'paymentStatus': 'unpaid',
        },
      )
      .toList();

  @override
  Future<String?> claimGroupSeat({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  }) async {
    if (claimError case final message?) {
      throw RepositoryActionException(message);
    }
    if (_bookings.length >= _capacity) return null; // honest failure (L-015)
    final id = 'gseat-${_bookings.length + 1}';
    _bookings.add({'id': id, 'athleteFirstName': athleteFirstName});
    return id;
  }

  @override
  Future<int> creditBalanceForService(String serviceId) async => 0;

  @override
  Future<List<dynamic>> getAthletes() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'group seat: shows seats-left from the roster and blocks the claim once full',
    (tester) async {
      final repo = _FakeGroupRepo();

      await tester.pumpWidget(
        // Providers wrap the WHOLE MaterialApp (not just `home`) — a modal
        // route's content renders in the Navigator's Overlay as a sibling of
        // the initial route, not nested under `home`'s subtree, so the repo
        // provider must sit above the Navigator to reach the sheet.
        MultiProvider(
          providers: [
            Provider<AppRepository>.value(value: repo),
            ChangeNotifierProvider(create: (_) => HomeProvider(repo)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showMultiBookingSheet(
                    context,
                    providerId: 'prov-1',
                    serviceId: 'svc-1',
                    serviceTitle: 'Youth Group Clinic',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Seats-left is sourced from the live roster (0 booked / 1 capacity).
      expect(find.text('1 seat left'), findsOneWidget);
      expect(find.text('Claim seat'), findsOneWidget);
      expect(find.text('Full'), findsNothing);

      // Claim the only seat.
      await tester.tap(find.text('Claim seat'));
      await tester.pumpAndSettle();

      // The slot is now full: the button flips to a disabled "Full" state and
      // the "seats left" copy is gone — never a stale/optimistic count.
      expect(find.text('Full'), findsWidgets); // the badge + the button label
      expect(find.text('1 seat left'), findsNothing);
      expect(find.text('Claim seat'), findsNothing);

      // A second claim attempt is impossible via the UI (button disabled) —
      // confirm the repo-level guard also honestly rejects an extra claim.
      expect(
        await repo.claimGroupSeat(
          serviceId: 'svc-1',
          slotDate: '2026-08-01',
          slotTime: '05:00 PM',
        ),
        isNull,
      );
    },
  );

  testWidgets('group seat: renders the server booking error verbatim', (
    tester,
  ) async {
    final repo = _FakeGroupRepo()
      ..claimError = 'This athlete already holds a seat in that session.';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepository>.value(value: repo),
          ChangeNotifierProvider(create: (_) => HomeProvider(repo)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showMultiBookingSheet(
                  context,
                  providerId: 'prov-1',
                  serviceId: 'svc-1',
                  serviceTitle: 'Youth Group Clinic',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claim seat'));
    await tester.pump();

    expect(
      find.text('This athlete already holds a seat in that session.'),
      findsOneWidget,
    );
    expect(repo._bookings, isEmpty);
  });
}
