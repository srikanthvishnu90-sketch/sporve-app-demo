import 'package:flutter/foundation.dart';
import '../../../core/data/app_repository.dart';

/// One turn in the conversational goal-intake thread (concierge ⇄ parent).
class IntakeMessage {
  final bool fromUser;
  final String text;
  const IntakeMessage(this.fromUser, this.text);
}

/// State + orchestration for **Prompt 2 — conversational goal intake**.
///
/// Reuses the AI-chat surface visually (see `GoalIntakeScreen`) but runs a
/// scripted, grounded flow: at most FOUR short questions (outcome → timeline →
/// budget → constraints), each answerable with a tappable chip OR free text.
/// A live, inline-editable summary card mirrors every answer. On [confirm] it
/// inserts `athlete_goals` (status active, `created_by = auth.uid()`, constraints
/// incl. Chicago-default lat/lng) + a `development_plans` row, then invokes
/// `generate-proposals`. Nothing books — the concierge only PROPOSES.
class GoalIntakeProvider with ChangeNotifier {
  GoalIntakeProvider(this._repo);
  final AppRepository _repo;

  // Chicago is where the live supply is — proposals are grounded to it unless
  // the parent says otherwise (contract §constraints).
  static const double _chicagoLat = 41.8781;
  static const double _chicagoLng = -87.6298;

  final List<IntakeMessage> _messages = [];
  List<IntakeMessage> get messages => List.unmodifiable(_messages);

  String _athleteId = '';
  String _athleteName = 'your athlete';
  String get athleteName => _athleteName;

  // step 0 outcome · 1 timeline · 2 budget · 3 constraints · 4 review/summary
  int _step = 0;
  int get step => _step;
  bool get atSummary => _step >= 4;

  bool _submitting = false;
  bool get submitting => _submitting;
  String? error;

  bool _done = false;
  bool get done => _done; // goal+plan created → navigate to Plan home
  String? createdPlanId;

  // ── Answers (all inline-editable from the summary card) ────────────────────
  String outcomeText = '';
  String outcomeType = 'other';
  String sport = 'General';
  String? targetDate; // 'YYYY-MM-DD' or null ("no rush")
  String targetLabel = 'No target date';
  int? budgetMonthlyCents; // null = skipped
  String budgetLabel = 'Not specified';
  final Set<String> _days = {};
  Set<String> get days => _days;
  String sessionTypePref = 'any'; // any | in_person | virtual
  double _lat = _chicagoLat;
  double _lng = _chicagoLng;
  double _maxDistanceKm = 40;
  double get maxDistanceKm => _maxDistanceKm;

  /// Travel radius the parent is willing to cover (written to
  /// `constraints.max_distance_km`). Clamped to a sane 5–80km range.
  void setMaxDistanceKm(double km) {
    _maxDistanceKm = km.clamp(5, 80).toDouble();
    notifyListeners();
  }

  Map<String, dynamic> get constraints => {
    'lat': _lat,
    'lng': _lng,
    'max_distance_km': _maxDistanceKm,
    'session_type_pref': sessionTypePref,
    'days': _days.toList(),
  };

  void start({required String athleteId, String? athleteName, String? sport}) {
    _athleteId = athleteId;
    final n = (athleteName ?? '').trim();
    _athleteName = n.isEmpty ? 'your athlete' : n.split(' ').first;
    if (sport != null && sport.trim().isNotEmpty) this.sport = sport.trim();
    _messages
      ..clear()
      ..add(IntakeMessage(false, _promptFor(0)));
    _step = 0;
    _submitting = false;
    _done = false;
    error = null;
    createdPlanId = null;
    outcomeText = '';
    outcomeType = 'other';
    targetDate = null;
    targetLabel = 'No target date';
    budgetMonthlyCents = null;
    budgetLabel = 'Not specified';
    _days.clear();
    sessionTypePref = 'any';
    _lat = _chicagoLat;
    _lng = _chicagoLng;
    _maxDistanceKm = 40;
    notifyListeners();
  }

  String _promptFor(int step) {
    switch (step) {
      case 0:
        return "What's the goal for $_athleteName? Say it however feels "
            'natural — I\'ll build a plan around it.';
      case 1:
        return 'Got it. Is there a timeline you\'re aiming for?';
      case 2:
        return 'What monthly budget feels comfortable? You can skip this.';
      case 3:
        return 'Last thing — any preferences on days, travel, or in-person '
            'vs virtual?';
      default:
        return "Here's your plan summary — edit anything, then confirm.";
    }
  }

  // ── Step 0: outcome (chip carries a type; free text is classified) ─────────
  void answerOutcome(String text, {String? type}) {
    final t = text.trim();
    if (t.isEmpty || _step != 0) return;
    outcomeText = t;
    outcomeType = type ?? _classifyOutcome(t);
    _advance(t);
  }

  String _classifyOutcome(String text) {
    final q = text.toLowerCase();
    if (RegExp(r'\b(team|varsity|roster|make the|tryout|squad)\b').hasMatch(q)) {
      return 'make_team';
    }
    if (RegExp(r'\b(college|elite|scholarship|d1|professional|national|recruit)\b')
        .hasMatch(q)) {
      return 'elite_pathway';
    }
    if (RegExp(r'\b(fun|fit|fitness|health|active|enjoy|social)\b').hasMatch(q)) {
      return 'fitness_fun';
    }
    if (RegExp(r'\b(skill|improve|develop|better|technique|fundamental|learn)\b')
        .hasMatch(q)) {
      return 'skill_development';
    }
    return 'other';
  }

  // ── Step 1: timeline ───────────────────────────────────────────────────────
  void answerTimeline(String display, {String? date}) {
    if (_step != 1) return;
    targetLabel = display;
    targetDate = date;
    _advance(display);
  }

  /// Free-text timeline: pull a 4-digit year if present ("by 2027") → Aug 1 of
  /// that year; otherwise store no date but keep the parent's words as the label.
  void answerTimelineText(String text) {
    final t = text.trim();
    if (t.isEmpty || _step != 1) return;
    final year = RegExp(r'\b(20\d{2})\b').firstMatch(t);
    if (year != null) {
      answerTimeline(t, date: '${year.group(1)}-08-01');
    } else {
      answerTimeline(t, date: null);
    }
  }

  // ── Step 2: budget ─────────────────────────────────────────────────────────
  void answerBudget(String display, {int? cents}) {
    if (_step != 2) return;
    budgetLabel = display;
    budgetMonthlyCents = cents;
    _advance(display);
  }

  void answerBudgetText(String text) {
    final t = text.trim();
    if (t.isEmpty || _step != 2) return;
    final m = RegExp(r'(\d{2,5})').firstMatch(t.replaceAll(',', ''));
    if (m != null) {
      final dollars = int.tryParse(m.group(1)!) ?? 0;
      answerBudget('~\$$dollars/mo', cents: dollars * 100);
    } else {
      answerBudget('Not specified', cents: null);
    }
  }

  // ── Step 3: constraints (multi-toggle; free text or "Done" completes) ──────
  void toggleDaySet(List<String> preset, String label) {
    // A preset chip (e.g. Weekends → Sat/Sun) toggles its whole set on/off.
    final allOn = preset.every(_days.contains);
    if (allOn) {
      _days.removeAll(preset);
    } else {
      _days.addAll(preset);
    }
    notifyListeners();
  }

  void setSessionType(String pref) {
    sessionTypePref = sessionTypePref == pref ? 'any' : pref;
    notifyListeners();
  }

  void finishConstraints([String? freeText]) {
    if (_step != 3) return;
    if (freeText != null && freeText.trim().isNotEmpty) {
      _parseConstraintText(freeText);
    }
    _messages.add(IntakeMessage(true, _constraintSummary()));
    _step = 4;
    _messages.add(IntakeMessage(false, _promptFor(4)));
    notifyListeners();
  }

  void _parseConstraintText(String text) {
    final q = text.toLowerCase();
    if (q.contains('weekend')) _days.addAll(['Sat', 'Sun']);
    if (q.contains('weekday')) {
      _days.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
    }
    if (q.contains('virtual') || q.contains('online')) {
      sessionTypePref = 'virtual';
    } else if (q.contains('in person') ||
        q.contains('in-person') ||
        q.contains('local')) {
      sessionTypePref = 'in_person';
    }
  }

  String _constraintSummary() {
    final parts = <String>[];
    if (_days.isNotEmpty) parts.add(_days.join('/'));
    if (sessionTypePref != 'any') {
      parts.add(sessionTypePref == 'in_person' ? 'in-person' : 'virtual');
    }
    return parts.isEmpty ? 'No specific preferences' : parts.join(' · ');
  }

  void _advance(String userText) {
    _messages.add(IntakeMessage(true, userText));
    _step += 1;
    _messages.add(IntakeMessage(false, _promptFor(_step)));
    notifyListeners();
  }

  // ── Inline summary editing (plain controls on the summary card) ────────────
  void editOutcome(String v) {
    outcomeText = v;
    if (v.trim().isNotEmpty) outcomeType = _classifyOutcome(v);
    notifyListeners();
  }

  void editSport(String v) {
    final t = v.trim();
    if (t.isNotEmpty) sport = t;
    notifyListeners();
  }

  void setTarget(String? date, String label) {
    targetDate = date;
    targetLabel = label;
    notifyListeners();
  }

  void setBudget(int? cents, String label) {
    budgetMonthlyCents = cents;
    budgetLabel = label;
    notifyListeners();
  }

  // ── Confirm: create goal + plan, then ask the engine for proposals ─────────
  Future<void> confirm() async {
    if (_submitting) return;
    if (outcomeText.trim().isEmpty) {
      error = 'Add a goal first.';
      notifyListeners();
      return;
    }
    _submitting = true;
    error = null;
    notifyListeners();
    try {
      // AI-formulate a concise headline from the parent's verbatim outcome.
      // Best-effort: failure never blocks confirm — fall back to a local
      // truncation. `outcomeText` is preserved verbatim (never overwritten).
      final headline = await _formulateHeadline(outcomeText.trim());
      final goalId = await _repo.createGoal({
        'athleteId': _athleteId,
        'outcomeText': outcomeText.trim(),
        'headline': headline,
        'outcomeType': outcomeType,
        'sport': sport,
        'targetDate': targetDate,
        if (budgetMonthlyCents != null)
          'budgetMonthlyCents': budgetMonthlyCents,
        'constraints': constraints,
      });
      if (goalId == null) {
        error =
            'Could not save your goal (there may already be an active goal for '
            'this sport). Please try again.';
        return;
      }
      final planId = await _repo.createPlan({
        'goalId': goalId,
        'title': _planTitle(),
        'phases': _starterPhases(),
      });
      createdPlanId = planId;
      if (planId != null) {
        // The engine writes up to 3 grounded proposals; the parent APPROVES
        // later. Failure here is non-fatal — the Plan screen retries on load.
        await _repo.generateProposals(planId);
      }
      _done = true;
    } catch (e) {
      error = 'Could not save your goal. Please try again.';
      debugPrint('goal intake confirm failed: $e');
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// Best-effort AI headline for [text]. Never throws — on any failure it
  /// returns a local truncation so [confirm] always proceeds.
  Future<String> _formulateHeadline(String text) async {
    if (text.isEmpty) return text;
    try {
      final h = await _repo.formulateGoalHeadline(text, sport: sport);
      final trimmed = h.trim();
      return trimmed.isEmpty ? _truncate(text) : trimmed;
    } catch (e) {
      debugPrint('formulateGoalHeadline (intake) failed: $e');
      return _truncate(text);
    }
  }

  String _truncate(String text) {
    final t = text.trim();
    if (t.length <= 40) return t;
    return '${t.substring(0, 39).trimRight()}…';
  }

  String _planTitle() {
    final t = outcomeText.trim();
    if (t.length <= 60) return t;
    return '${t.substring(0, 57)}…';
  }

  List<Map<String, dynamic>> _starterPhases() => [
    {'name': 'Foundation', 'status': 'active'},
    {'name': 'Development', 'status': 'upcoming'},
    {'name': 'Performance', 'status': 'upcoming'},
  ];
}
