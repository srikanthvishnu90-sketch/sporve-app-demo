import 'package:flutter/foundation.dart';
import '../../../core/data/app_repository.dart';

/// One automated-message event type and its display metadata.
class LifecycleEvent {
  final String type;
  final String label;
  final String description;

  /// Logistics types may use 'auto'. Substantive types are draft-only (coach
  /// approval always required) — 'auto' is disabled for them in the UI and at DB.
  final bool isLogistics;
  const LifecycleEvent(
    this.type,
    this.label,
    this.description,
    this.isLogistics,
  );
}

const List<LifecycleEvent> kLifecycleEvents = [
  LifecycleEvent(
    'booking_confirmed',
    'Booking confirmed',
    'Sent when a session is confirmed.',
    true,
  ),
  LifecycleEvent(
    'reminder_24h',
    '24-hour reminder',
    'Sent the day before a session.',
    true,
  ),
  LifecycleEvent(
    'post_session',
    'Post-session check-in',
    'A logistics/feedback nudge after a session (not a progress report).',
    false,
  ),
  LifecycleEvent(
    'no_show_followup',
    'Missed-session follow-up',
    'A gentle check-in after a missed session.',
    false,
  ),
  LifecycleEvent(
    'rebook_nudge',
    'Re-book nudge',
    'A friendly nudge when it has been a while.',
    false,
  ),
];

/// Drives the coach's automated-message preferences and the approval queue of
/// AI-drafted lifecycle messages. Provider/ChangeNotifier only (project rule).
class LifecycleController with ChangeNotifier {
  final AppRepository _repo;
  LifecycleController(this._repo);

  // event_type -> mode ('off'|'draft'|'auto'); absent => default 'draft'.
  final Map<String, String> _modes = {};
  List<Map<String, dynamic>> _drafts = [];
  bool _loadingPrefs = false;
  bool _loadingDrafts = false;
  String? _error;

  String modeFor(String eventType) => _modes[eventType] ?? 'draft';
  List<Map<String, dynamic>> get drafts => _drafts;
  bool get loadingPrefs => _loadingPrefs;
  bool get loadingDrafts => _loadingDrafts;
  String? get error => _error;

  Future<void> loadPrefs() async {
    _loadingPrefs = true;
    notifyListeners();
    final rows = await _repo.getLifecyclePrefs();
    _modes.clear();
    for (final r in rows) {
      final t = r['eventType']?.toString();
      final m = r['mode']?.toString();
      if (t != null && m != null) _modes[t] = m;
    }
    _loadingPrefs = false;
    notifyListeners();
  }

  /// Returns true if the mode was saved. 'auto' on a non-logistics type is
  /// rejected (DB CHECK + client guard) and returns false without changing state.
  Future<bool> setMode(String eventType, String mode) async {
    final ok = await _repo.setLifecyclePref(eventType, mode);
    if (ok) {
      _modes[eventType] = mode;
    } else {
      _error = 'That mode is not allowed for this message type.';
    }
    notifyListeners();
    return ok;
  }

  Future<void> loadDrafts() async {
    _loadingDrafts = true;
    notifyListeners();
    _drafts = await _repo.getLifecycleDrafts();
    _loadingDrafts = false;
    notifyListeners();
  }

  /// Coach approves (optionally edited) -> server sends. Removes the row from the
  /// queue on success. Returns null on success, or an error string.
  Future<String?> approveAndSend(String id, String body) async {
    final res = await _repo.approveLifecycleMessage(id, body: body);
    if (res['error'] != null) {
      _error = res['error'].toString();
      notifyListeners();
      return _error;
    }
    _drafts = _drafts.where((d) => d['id'] != id).toList();
    notifyListeners();
    return null;
  }
}
