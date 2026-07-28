import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/data/app_repository.dart';

enum ParentUpdateStage { input, clarifying, draft, approved, sent }

/// Drives the "Write parent update" flow: raw notes -> session-note-summarize ->
/// (clarify | editable draft) -> autosave draft -> explicit Approve. Nothing is
/// ever sent from here; Approve only flips status to 'approved'.
class ParentUpdateController extends ChangeNotifier {
  ParentUpdateController(this._repo);
  final AppRepository _repo;

  // ── Booking context (pre-filled from the completed booking) ────────────────
  String bookingId = '';
  String childId = '';
  String childFirstName = '';
  String sport = '';
  String? lastUpdateSummary; // optional continuity anchor (history wiring is later)

  ParentUpdateStage stage = ParentUpdateStage.input;
  bool busy = false;
  String? error;

  String rawNotes = '';
  List<String> clarifyQuestions = [];

  // ── Structured session note (Prompt 5) — provider-authored, feeds the ────────
  // grounded progress digest. Parents never read these raw fields.
  List<String> focusAreas = [];
  int? effort; // 1–5
  String progressNote = '';

  // ── Editable draft fields ──────────────────────────────────────────────────
  String summaryBody = '';
  List<String> skillsWorked = [];
  String progressSignal = '';
  List<String> practiceSuggestions = [];
  String encouragement = '';
  List<String> removed = [];

  String? _sessionNoteId;
  String? _parentUpdateId;
  String? get parentUpdateId => _parentUpdateId;

  bool _saving = false;
  bool get saving => _saving;
  DateTime? lastSavedAt;
  Timer? _saveTimer;

  void init({
    required String bookingId,
    required String childId,
    required String childFirstName,
    required String sport,
  }) {
    _saveTimer?.cancel();
    this.bookingId = bookingId;
    this.childId = childId;
    this.childFirstName = childFirstName;
    this.sport = sport;
    stage = ParentUpdateStage.input;
    busy = false;
    error = null;
    rawNotes = '';
    clarifyQuestions = [];
    focusAreas = [];
    effort = null;
    progressNote = '';
    summaryBody = '';
    skillsWorked = [];
    progressSignal = '';
    practiceSuggestions = [];
    encouragement = '';
    removed = [];
    _sessionNoteId = null;
    _parentUpdateId = null;
    lastSavedAt = null;
    notifyListeners();
  }

  void setRawNotes(String v) => rawNotes = v;
  void setProgressNote(String v) => progressNote = v;

  void addFocusArea(String v) {
    final t = v.trim();
    if (t.isEmpty || focusAreas.contains(t)) return;
    focusAreas.add(t);
    notifyListeners();
  }

  void removeFocusArea(int i) {
    focusAreas.removeAt(i);
    notifyListeners();
  }

  /// Toggle the 1–5 effort rating (tapping the selected value clears it).
  void setEffort(int v) {
    effort = (effort == v) ? null : v;
    notifyListeners();
  }

  /// Persists the raw notes, then asks the model for a draft (or clarification).
  Future<void> generate() async {
    if (rawNotes.trim().isEmpty) {
      error = 'Add some notes first.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      // One session_notes row per generation (preserves the coach's raw input +
      // the structured focus_areas / effort / progress_note that feed the digest).
      _sessionNoteId = await _repo.createSessionNote({
        'rawNotes': rawNotes.trim(),
        'bookingId': bookingId,
        'childId': childId,
        'focusAreas': focusAreas,
        if (effort != null) 'effort': effort,
        'progressNote': progressNote.trim(),
      });

      final res = await _repo.summarizeSessionNote({
        'rawNotes': rawNotes.trim(),
        'childFirstName': childFirstName,
        'sport': sport,
        if (lastUpdateSummary != null) 'lastUpdateSummary': lastUpdateSummary,
      });
      if (res['error'] != null) {
        error = res['error'].toString();
        return;
      }
      final result = (res['result'] as Map?) ?? {};
      removed = ((res['removed'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

      if (result['type']?.toString() == 'needs_clarification') {
        clarifyQuestions = ((result['questions'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        stage = ParentUpdateStage.clarifying;
      } else {
        summaryBody = (result['summary_body'] ?? '').toString();
        skillsWorked = ((result['skills_worked'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        progressSignal = (result['progress_signal'] ?? '').toString();
        practiceSuggestions =
            ((result['practice_suggestions'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList();
        encouragement = (result['encouragement'] ?? '').toString();
        clarifyQuestions = [];
        stage = ParentUpdateStage.draft;
        await _persistDraft(); // initial autosave so a row exists immediately
      }
    } catch (e) {
      error = 'Could not draft the update. Please try again.';
      debugPrint('parent-update generate failed: $e');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // ── Editable setters — each schedules a debounced autosave ──────────────────
  void editSummary(String v) {
    summaryBody = v;
    _scheduleSave();
  }

  void editProgress(String v) {
    progressSignal = v;
    _scheduleSave();
  }

  void editEncouragement(String v) {
    encouragement = v;
    _scheduleSave();
  }

  void addSkill(String v) {
    if (v.trim().isEmpty) return;
    skillsWorked.add(v.trim());
    notifyListeners();
    _scheduleSave();
  }

  void removeSkill(int i) {
    skillsWorked.removeAt(i);
    notifyListeners();
    _scheduleSave();
  }

  void addSuggestion(String v) {
    if (v.trim().isEmpty) return;
    practiceSuggestions.add(v.trim());
    notifyListeners();
    _scheduleSave();
  }

  void removeSuggestion(int i) {
    practiceSuggestions.removeAt(i);
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    if (stage != ParentUpdateStage.draft) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1200), _persistDraft);
  }

  Future<void> _persistDraft() async {
    if (stage != ParentUpdateStage.draft) return;
    _saving = true;
    notifyListeners();
    try {
      final id = await _repo.upsertParentUpdateDraft({
        if (_parentUpdateId != null) 'id': _parentUpdateId,
        'sessionNoteId': _sessionNoteId,
        'bookingId': bookingId,
        'childId': childId,
        'summaryBody': summaryBody,
        'skillsWorked': skillsWorked,
        'progressSignal': progressSignal,
        'practiceSuggestions': practiceSuggestions,
        'encouragement': encouragement,
      });
      if (id != null) _parentUpdateId = id;
      lastSavedAt = DateTime.now();
    } catch (e) {
      debugPrint('parent-update autosave failed: $e');
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Explicit, coach-initiated approval. Saves the latest edits first, then flips
  /// status to 'approved'. Sending is a separate step — never happens here.
  Future<bool> approve() async {
    _saveTimer?.cancel();
    await _persistDraft();
    if (_parentUpdateId == null) {
      error = 'Could not save the draft, so it can’t be approved yet.';
      notifyListeners();
      return false;
    }
    busy = true;
    notifyListeners();
    try {
      final row = await _repo.approveParentUpdate(_parentUpdateId!);
      if (row == null) {
        error = 'Could not approve. Please try again.';
        return false;
      }
      stage = ParentUpdateStage.approved;
      return true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Explicit, deterministic send of an APPROVED update. Routes the finalized
  /// content to the guardian(s) via the inbox channel and flips status to 'sent'.
  /// No AI here — the content is already finalized.
  Future<bool> send() async {
    if (_parentUpdateId == null) {
      error = 'Nothing to send yet.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final res = await _repo.sendParentUpdate(_parentUpdateId!);
      if (res['error'] != null) {
        error = res['error'].toString();
        return false;
      }
      stage = ParentUpdateStage.sent;
      return true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
