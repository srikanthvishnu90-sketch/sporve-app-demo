import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';

/// Coach OS — WAITLIST state (P0 #3). Shared by both sides: the client joins a
/// full program's list; the coach reads/manages their programs' lists. Thin
/// over [WaitlistRepository]; RLS does the scoping, so this never filters by
/// hand. No money, no booking is created here (promotion rides addBooking).
class WaitlistController extends ChangeNotifier {
  WaitlistController(this._repo);
  final AppRepository _repo;

  // Provider-side list (all of the coach's programs' active entries).
  List<Map<String, dynamic>> _providerEntries = [];
  List<Map<String, dynamic>> get providerEntries =>
      List.unmodifiable(_providerEntries);

  // Family-side list (this searcher's own entries).
  List<Map<String, dynamic>> _myEntries = [];
  List<Map<String, dynamic>> get myEntries => List.unmodifiable(_myEntries);

  bool _loading = false;
  bool get loading => _loading;
  bool _error = false;
  bool get error => _error;

  // Provider Model Rebuild #8 — active OFFERS (drafted/sent/accepted), keyed to
  // program_waitlist entries by entryId. Supplementary to the entries list: a
  // failure here degrades to "no offer info shown" rather than a hard error,
  // since the entries themselves still loaded fine.
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> get offers => List.unmodifiable(_offers);

  Future<void> loadForProvider() async {
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      _providerEntries = await _repo.getWaitlistForProvider();
    } catch (e) {
      debugPrint('WaitlistController.loadForProvider failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
    await loadOffers();
  }

  Future<void> loadOffers() async {
    try {
      _offers = await _repo.getWaitlistOffers();
      notifyListeners();
    } catch (e) {
      debugPrint('WaitlistController.loadOffers failed: $e');
    }
  }

  /// The most relevant live/recent offer for one waitlist entry, or null.
  Map<String, dynamic>? offerForEntry(String entryId) {
    Map<String, dynamic>? found;
    for (final o in _offers) {
      if (o['entryId'] == entryId) found = o;
    }
    return found;
  }

  /// Coach: (re)draft the offer's ai_draft message. Returns the repo's JSON
  /// body so the caller can toast the outcome; always reloads offers after.
  Future<Map<String, dynamic>> draftOffer(String offerId) async {
    final res = await _repo.draftWaitlistOffer(offerId);
    await loadOffers();
    return res;
  }

  Future<void> loadMine() async {
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      _myEntries = await _repo.getMyWaitlistEntries();
    } catch (e) {
      debugPrint('WaitlistController.loadMine failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Join a full program's waitlist. Returns the new entry id (null on failure).
  Future<String?> join(Map<String, dynamic> entry) async {
    try {
      final id = await _repo.joinWaitlist(entry);
      if (id != null) await loadMine();
      return id;
    } catch (e) {
      debugPrint('WaitlistController.join failed: $e');
      return null;
    }
  }

  Future<bool> cancel(String id) async {
    final ok = await _repo.cancelWaitlistEntry(id);
    if (ok) {
      _myEntries.removeWhere((e) => e['_id'] == id);
      notifyListeners();
    }
    return ok;
  }

  /// Coach lifecycle move (offered/cancelled/expired/converted).
  Future<bool> setStatus(String id, String status) async {
    final ok = await _repo.updateWaitlistStatus(id, status);
    if (ok) {
      if (status == 'waiting' || status == 'offered') {
        final i = _providerEntries.indexWhere((e) => e['_id'] == id);
        if (i != -1) _providerEntries[i]['status'] = status;
      } else {
        _providerEntries.removeWhere((e) => e['_id'] == id);
      }
      notifyListeners();
    }
    return ok;
  }
}
