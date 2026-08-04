import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';

/// Provider Model Rebuild — item #6 (a): the org scheduling GRID controller.
/// Thin over [OrgSchedulingRepository.orgScheduleGrid] — admin-gated at the DB
/// (org_schedule_grid, 20260729_000600); a non-admin caller gets an EMPTY list
/// by design (mirrors the camp-roster L-005/L-024 pattern), so this controller
/// does not try to distinguish "not an org admin" from "nothing booked yet".
class OrgGridController extends ChangeNotifier {
  OrgGridController(this._repo);

  final AppRepository _repo;

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> get rows => List.unmodifiable(_rows);

  // A one-week window, starting today. yyyy-MM-dd (calendar days, never toLocal).
  String _fromDate = _todayIso();
  String get fromDate => _fromDate;
  String get toDate => _addDaysIso(_fromDate, 6);

  bool _loading = false;
  bool get loading => _loading;
  bool _error = false;
  bool get error => _error;

  static String _todayIso() => _iso(DateTime.now());
  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _addDaysIso(String iso, int days) {
    final d = DateTime.tryParse(iso) ?? DateTime.now();
    return _iso(d.add(Duration(days: days)));
  }

  Future<void> load({String? fromDate}) async {
    if (fromDate != null) _fromDate = fromDate;
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      _rows = await _repo.orgScheduleGrid(fromDate: _fromDate, toDate: toDate);
    } catch (e) {
      debugPrint('OrgGridController.load failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setFromDate(String iso) => load(fromDate: iso);
  Future<void> shiftWeek(int deltaWeeks) => load(fromDate: _addDaysIso(_fromDate, deltaWeeks * 7));

  /// True when 2+ rows in this window conflict on the same venue+slot — used to
  /// surface a top-level banner in addition to the per-row flag.
  bool get hasAnyConflict => _rows.any((r) => r['hasConflict'] == true);

  /// Rows grouped by venue (locationName, falling back to "Unassigned venue"),
  /// each venue's rows sorted by date then time — the "trainers × venues" read.
  Map<String, List<Map<String, dynamic>>> get byVenue {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final r in _rows) {
      final venue = (r['locationName'] ?? '').toString();
      final key = venue.isEmpty ? 'Unassigned venue' : venue;
      (out[key] ??= []).add(r);
    }
    for (final list in out.values) {
      list.sort((a, b) {
        final dc = (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString());
        if (dc != 0) return dc;
        return (a['slotTime'] ?? '').toString().compareTo((b['slotTime'] ?? '').toString());
      });
    }
    return out;
  }
}
