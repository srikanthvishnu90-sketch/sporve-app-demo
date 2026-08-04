import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';

/// Provider Model Rebuild — item #7 (deferred UI): the camp ops surface. Thin
/// over [CampRepository]. STAFF-ONLY: a non-staff caller's `campRoster` returns
/// an empty list by design (RLS/gate, L-005) — this controller does not try to
/// distinguish "no camp staffed" from "no families registered yet"; the view
/// renders one honest empty state either way. Every write returns bool/Map so
/// the view can surface honest failure (L-015) and never silently swallow it.
class CampRosterController extends ChangeNotifier {
  CampRosterController(this._repo, {required this.serviceId});

  final AppRepository _repo;
  final String serviceId;

  List<Map<String, dynamic>> _roster = [];
  List<Map<String, dynamic>> get roster => List.unmodifiable(_roster);

  String _day = _todayIso();
  String get day => _day;

  bool _loading = false;
  bool get loading => _loading;
  bool _error = false;
  bool get error => _error;

  // Per-rosterId check-in-in-flight guard, so a double-tap can't double-fire.
  final Set<String> _checkingIn = {};
  bool isCheckingIn(String rosterId) => _checkingIn.contains(rosterId);

  bool _drafting = false;
  bool get drafting => _drafting;

  static String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> load({String? day}) async {
    if (day != null) _day = day;
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      _roster = await _repo.campRoster(serviceId: serviceId, day: _day);
    } catch (e) {
      debugPrint('CampRosterController.load failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setDay(String iso) => load(day: iso);

  /// Tap check-in for one roster entry, today's [day]. Returns true on
  /// success; the view shows an error and leaves the row untouched on false
  /// (L-015 — never fake a check-in locally).
  Future<bool> checkIn(String rosterId) async {
    if (_checkingIn.contains(rosterId)) return false;
    _checkingIn.add(rosterId);
    notifyListeners();
    try {
      final at = await _repo.campCheckIn(rosterId: rosterId, day: _day);
      if (at == null) return false;
      final i = _roster.indexWhere((r) => r['rosterId'] == rosterId);
      if (i != -1) _roster[i] = {..._roster[i], 'checkedInAt': at.toIso8601String()};
      return true;
    } catch (e) {
      debugPrint('CampRosterController.checkIn failed: $e');
      return false;
    } finally {
      _checkingIn.remove(rosterId);
      notifyListeners();
    }
  }

  /// EOD recap draft — every registered family gets a grounded per-family
  /// draft (never sent). Returns the repo's result map (has 'error' on
  /// failure); never throws.
  Future<Map<String, dynamic>> draftRecap({
    List<String> skills = const [],
    int? effort,
    String? note,
  }) async {
    _drafting = true;
    notifyListeners();
    try {
      return await _repo.campRecapDraft(
        serviceId: serviceId,
        day: _day,
        skills: skills,
        effort: effort,
        note: note,
      );
    } finally {
      _drafting = false;
      notifyListeners();
    }
  }

  /// Bulk announcement draft — one coach-only draft per registered family
  /// (never sent). Returns the repo's result map (has 'error' on failure).
  Future<Map<String, dynamic>> draftBroadcast(String message) async {
    _drafting = true;
    notifyListeners();
    try {
      return await _repo.campBroadcast(serviceId: serviceId, message: message);
    } finally {
      _drafting = false;
      notifyListeners();
    }
  }
}
