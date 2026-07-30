import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';

/// Coach OS — RECURRING WEEKLY SLOTS state (AI Front Office #1). The coach's
/// standing weekly availability template ("Tuesdays 5pm, 60 min, $80"): publish
/// once, it exists every week. Thin over [RecurringSlotRepository]; RLS scopes
/// every read/write to the owning coach. Skipping one week writes a slot
/// exception WITHOUT deleting the slot. No money moves here (a slot is a quote).
class RecurringSlotsController extends ChangeNotifier {
  RecurringSlotsController(this._repo);
  final AppRepository _repo;

  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> get slots => List.unmodifiable(_slots);

  // slotId -> the ISO yyyy-MM-dd dates that slot is skipped.
  final Map<String, List<String>> _exceptions = {};
  List<String> exceptionsFor(String slotId) =>
      List.unmodifiable(_exceptions[slotId] ?? const []);

  bool _loading = false;
  bool get loading => _loading;
  bool _error = false;
  bool get error => _error;
  bool _saving = false;
  bool get saving => _saving;

  Future<void> load() async {
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      _slots = await _repo.getMyRecurringSlots();
      _exceptions.clear();
      for (final s in _slots) {
        final id = s['_id']?.toString();
        if (id != null) {
          _exceptions[id] = await _repo.getSlotExceptions(id);
        }
      }
    } catch (e) {
      debugPrint('RecurringSlotsController.load failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Create one weekly slot. [startTime] is 24h "HH:mm"; [priceCents] is integer
  /// cents. Returns true on success (and reloads).
  Future<bool> addSlot({
    required int dayOfWeek,
    required String startTime,
    required int durationMinutes,
    required int priceCents,
    int capacity = 1,
  }) async {
    _saving = true;
    notifyListeners();
    try {
      final id = await _repo.createRecurringSlot({
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'durationMinutes': durationMinutes,
        'priceCents': priceCents,
        'capacity': capacity,
      });
      if (id != null) await load();
      return id != null;
    } catch (e) {
      debugPrint('RecurringSlotsController.addSlot failed: $e');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Pause/resume a slot (never deletes it).
  Future<bool> setActive(String slotId, bool active) async {
    final ok = await _repo.setRecurringSlotActive(slotId, active);
    if (ok) {
      final i = _slots.indexWhere((s) => s['_id'] == slotId);
      if (i != -1) _slots[i]['active'] = active;
      notifyListeners();
    }
    return ok;
  }

  /// Skip ONE week ([date] ISO yyyy-MM-dd). Records an exception; the slot stays.
  Future<bool> skipWeek(String slotId, String date, {String? reason}) async {
    final ok = await _repo.skipRecurringSlotWeek(slotId, date, reason: reason);
    if (ok) {
      _exceptions[slotId] = await _repo.getSlotExceptions(slotId);
      notifyListeners();
    }
    return ok;
  }
}
