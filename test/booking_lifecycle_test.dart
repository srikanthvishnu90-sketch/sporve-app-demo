// Verifies the provider booking lifecycle PERSISTS status transitions (the gap:
// confirm/decline used to only flip in-memory flags). Each action must call
// updateBookingStatus with the right status and reflect it locally; a backend
// failure must NOT change local state.
//   flutter test test/booking_lifecycle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/presentation/provider/controllers/provider_controller.dart';

class _FakeRepo implements AppRepository {
  final List<(String, String)> statusCalls = [];
  bool ok = true;

  @override
  Future<List<dynamic>> getBookings() async => getBookingsOrThrow();

  @override
  Future<List<dynamic>> getBookingsOrThrow() async => [
        {'_id': 'b1', 'status': 'pending', 'athleteId': <String, dynamic>{}},
      ];

  @override
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    statusCalls.add((bookingId, status));
    return ok;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<(ProviderController, _FakeRepo)> _seed() async {
  final repo = _FakeRepo();
  final c = ProviderController(repo);
  await c.fetchProviderBookings(); // loads the one pending booking
  return (c, repo);
}

void main() {
  test('confirm persists + reflects locally', () async {
    final (c, repo) = await _seed();
    expect(await c.confirmSession('b1'), true);
    expect(repo.statusCalls.last, ('b1', 'confirmed'));
    expect(c.sessions.first.isConfirmed, true);
  });

  test('complete persists; sets completed + confirmed', () async {
    final (c, repo) = await _seed();
    expect(await c.completeSession('b1'), true);
    expect(repo.statusCalls.last, ('b1', 'completed'));
    expect(c.sessions.first.isCompleted, true);
    expect(c.sessions.first.isConfirmed, true);
  });

  test('no-show persists; sets noShow, not confirmed', () async {
    final (c, repo) = await _seed();
    expect(await c.markNoShow('b1'), true);
    expect(repo.statusCalls.last, ('b1', 'no_show'));
    expect(c.sessions.first.isNoShow, true);
    expect(c.sessions.first.isConfirmed, false);
  });

  test('decline persists', () async {
    final (c, repo) = await _seed();
    expect(await c.declineSession('b1'), true);
    expect(repo.statusCalls.last, ('b1', 'declined'));
    expect(c.sessions.first.isDeclined, true);
  });

  test('backend failure leaves local state unchanged', () async {
    final (c, repo) = await _seed();
    repo.ok = false;
    expect(await c.confirmSession('b1'), false);
    expect(c.sessions.first.isConfirmed, false, reason: 'no optimistic lie on failure');
  });

  test('mock-id sessions stay local (no backend call)', () async {
    final repo = _FakeRepo();
    final c = ProviderController(repo);
    // a mock session id (req_/conf_/other_) must not hit the backend
    expect(await c.confirmSession('req_123'), true);
    expect(repo.statusCalls, isEmpty);
  });
}
