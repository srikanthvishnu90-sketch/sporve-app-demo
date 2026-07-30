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
