// Provider Model Rebuild #8 — waitlist OFFER engine (mock/demo layer). Mirrors
// the backend invariants in 20260729_000800_waitlist_offers.sql:
//   • an entry moved to 'offered' gets a time-boxed OFFER (drafted, 24h window) —
//     the UI surfaces its expiry as a countdown.
//   • drafting an offer calls the invoke path (waitlist-offer-draft equivalent)
//     and is idempotent (a re-fire on an already-drafted offer is a no-op).
//   • accepting rides the EXISTING claim path (no new booking path) and is
//     honest-failure (L-015): not-yet-sent / expired offers accept to null.
// flutter test test/waitlist_offer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/mock_repository.dart';
import 'package:flutter_structure/presentation/shared/controllers/waitlist_controller.dart';

void main() {
  const repo = MockRepository();

  Future<String> newEntry() async {
    final id = await repo.joinWaitlist({
      'programId': 'prog-1',
      'programTitle': 'Elite Soccer Clinic',
      'athleteFirstName': 'Maya',
      'athleteAgeBand': '9-11',
    });
    expect(id, isNotNull);
    return id!;
  }

  test('moving an entry to offered creates a live offer with a 24h expiry',
      () async {
    final id = await newEntry();
    final ok = await repo.updateWaitlistStatus(id, 'offered');
    expect(ok, isTrue);

    final offers = await repo.getWaitlistOffers();
    final offer = offers.firstWhere((o) => o['entryId'] == id);
    expect(offer['status'], 'drafted');
    final expiresAt = DateTime.parse(offer['expiresAt'] as String);
    final hoursLeft = expiresAt.difference(DateTime.now()).inHours;
    expect(hoursLeft, greaterThanOrEqualTo(23));
    expect(hoursLeft, lessThanOrEqualTo(24));
  });

  test('an offered entry surfaces a countdown via WaitlistController', () async {
    final id = await newEntry();
    await repo.updateWaitlistStatus(id, 'offered');

    final c = WaitlistController(repo);
    await c.loadForProvider();

    final entry = c.providerEntries.firstWhere((e) => e['_id'] == id);
    expect(entry['status'], 'offered');

    final offer = c.offerForEntry(id);
    expect(offer, isNotNull, reason: 'the countdown UI reads this');
    expect(offer!['status'], 'drafted');
    final expiresAt = DateTime.tryParse(offer['expiresAt']?.toString() ?? '');
    expect(expiresAt, isNotNull);
    expect(expiresAt!.isAfter(DateTime.now()), isTrue,
        reason: 'a fresh offer has time left on its countdown');
  });

  test('drafting an offer calls the invoke path and is idempotent', () async {
    final id = await newEntry();
    await repo.updateWaitlistStatus(id, 'offered');
    final offers = await repo.getWaitlistOffers();
    final offerId = offers.firstWhere((o) => o['entryId'] == id)['_id'] as String;

    final res = await repo.draftWaitlistOffer(offerId);
    expect(res['result'], 'drafted');
    expect(res['draft_id'], isNotNull);
    expect(res['reply_text'], contains('Maya'));

    // Idempotent re-fire (mirrors the edge fn: already has a draft -> skipped).
    final again = await repo.draftWaitlistOffer(offerId);
    expect(again['skipped'], isNotNull);
    expect(again['result'], isNull);
  });

  test('draftWaitlistOffer fails honestly for an unknown offer id', () async {
    final res = await repo.draftWaitlistOffer('nope');
    expect(res['error'], isNotNull);
  });

  test('accept rides the existing claim (mock): only a sent, unexpired offer '
      'converts; a not-yet-sent offer is honest-failure', () async {
    final id = await newEntry();
    await repo.updateWaitlistStatus(id, 'offered');
    final offers = await repo.getWaitlistOffers();
    final offerId = offers.firstWhere((o) => o['entryId'] == id)['_id'] as String;

    // Still 'drafted' (never auto-sent, L-003) -> accept is honest-failure.
    final tooEarly = await repo.acceptWaitlistOffer(offerId);
    expect(tooEarly, isNull);

    // Simulate the coach sending the draft (the real flow: resolve_draft ->
    // trg_waitlist_offer_on_message_sent flips drafted -> sent).
    final sentOffers = await repo.getWaitlistOffers();
    final offer = sentOffers.firstWhere((o) => o['_id'] == offerId);
    offer['status'] = 'sent';

    final bookingId = await repo.acceptWaitlistOffer(offerId);
    expect(bookingId, isNotNull, reason: 'claims the seat, no new booking path');

    final afterOffers = await repo.getWaitlistOffers();
    final accepted = afterOffers.firstWhere((o) => o['_id'] == offerId);
    expect(accepted['status'], 'accepted');

    // A second accept on the now-resolved offer is honest-failure, not a
    // silent double-claim.
    final again = await repo.acceptWaitlistOffer(offerId);
    expect(again, isNull);
  });

  test('decline rolls the entry back to waiting', () async {
    final id = await newEntry();
    await repo.updateWaitlistStatus(id, 'offered');
    final offers = await repo.getWaitlistOffers();
    final offerId = offers.firstWhere((o) => o['entryId'] == id)['_id'] as String;

    final ok = await repo.declineWaitlistOffer(offerId);
    expect(ok, isTrue);

    final entries = await repo.getMyWaitlistEntries();
    final entry = entries.firstWhere((e) => e['_id'] == id);
    expect(entry['status'], 'waiting');
  });
}
