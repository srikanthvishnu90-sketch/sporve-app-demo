import 'package:flutter/foundation.dart';
import '../../../core/data/app_repository.dart';

/// The kind of artifact a timeline row represents.
enum TimelineEntryKind {
  /// A coach's SENT parent_update (per-session skill tags + note).
  update,

  /// A grounded, backend-authored progress_digest (rolls up N sessions).
  digest,
}

/// One reverse-chron row in a child's development timeline. Wraps the raw mapped
/// map from the repository plus a parsed [date] used only for sorting/display.
class TimelineEntry {
  TimelineEntry({
    required this.kind,
    required this.date,
    required this.data,
  });

  final TimelineEntryKind kind;
  final DateTime date;
  final Map<String, dynamic> data;

  /// The first worked skill on an update, if any — the natural milestone seed.
  String? get headlineSkill {
    if (kind != TimelineEntryKind.update) return null;
    final skills = (data['skillsWorked'] as List?)
        ?.map((e) => e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return (skills == null || skills.isEmpty) ? null : skills.first;
  }
}

/// Parent-facing P0 #4 surface: the child's DEVELOPMENT TIMELINE. Merges the
/// coach's SENT `parent_updates` with the grounded `progress_digests` for the
/// selected child into a single reverse-chron feed. Reads are doubly guarded —
/// RLS server-side AND a child-ownership filter in the repository — so a guardian
/// only ever sees their own child's artifacts. This is the retention lock: the
/// development record of a kid that a text thread can't replicate.
class AthleteTimelineController extends ChangeNotifier {
  AthleteTimelineController(this._repo);
  final AppRepository _repo;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> children = [];
  String? selectedChildId;
  List<TimelineEntry> entries = [];

  Map<String, dynamic>? get selectedChild {
    for (final c in children) {
      if (c['_id']?.toString() == selectedChildId) return c;
    }
    return null;
  }

  String get selectedChildName =>
      (selectedChild?['firstName'] ?? 'this athlete').toString();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final ath = await _repo.getAthletes();
      children = ath.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      selectedChildId =
          children.isNotEmpty ? children.first['_id']?.toString() : null;
      await _loadEntries();
    } catch (e) {
      error = 'Could not load the timeline.';
      debugPrint('athlete-timeline load failed: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectChild(String childId) async {
    if (childId == selectedChildId) return;
    selectedChildId = childId;
    await _loadEntries();
  }

  Future<void> _loadEntries() async {
    final id = selectedChildId;
    if (id == null) {
      entries = [];
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      // Two parent-readable artifact streams; session_notes are coach-only
      // (COPPA) and intentionally NOT read here.
      final results = await Future.wait([
        _repo.getParentUpdatesForChild(id),
        _repo.getProgressDigestsForChild(id),
      ]);
      final updates = results[0];
      final digests = results[1];

      final merged = <TimelineEntry>[
        for (final u in updates)
          TimelineEntry(
            kind: TimelineEntryKind.update,
            date: _parseDate(u['sentAt'] ?? u['createdAt']),
            data: u,
          ),
        for (final d in digests)
          TimelineEntry(
            kind: TimelineEntryKind.digest,
            date: _parseDate(d['createdAt']),
            data: d,
          ),
      ];
      merged.sort((a, b) => b.date.compareTo(a.date));
      entries = merged;
    } catch (e) {
      entries = [];
      debugPrint('athlete-timeline fetch failed: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static DateTime _parseDate(dynamic iso) =>
      DateTime.tryParse((iso ?? '').toString())?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
