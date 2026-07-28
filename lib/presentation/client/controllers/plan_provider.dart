import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../../core/data/app_repository.dart';
import '../../../core/utils/session_time.dart';

/// State for **Prompt 3 — Plan home** (and Prompt 5 progress rendering).
///
/// Loads the active athlete's goal + development plan, invokes `plan-progress`
/// (cheap; no-ops server-side below thresholds), then reads the latest grounded
/// `progress_digest`, the engine's `proposed` proposals (rank order), and the
/// next booked session. The concierge PROPOSES here — approval runs the EXISTING
/// booking flow (see `BookingFlowScreen`); decline flips status + backfills.
class PlanProvider with ChangeNotifier {
  PlanProvider(this._repo);
  final AppRepository _repo;

  bool _loading = false;
  bool get loading => _loading;
  bool _loadedOnce = false;
  bool get loadedOnce => _loadedOnce;
  String? error;

  Map<String, dynamic>? athlete;
  Map<String, dynamic>? goal;
  Map<String, dynamic>? plan;
  List<Map<String, dynamic>> proposals = [];
  Map<String, dynamic>? digest;
  Map<String, dynamic>? nextBooking;

  /// All athletes for the signed-in parent (drives the §11 athlete switcher).
  /// The switcher only shows when there is more than one.
  List<Map<String, dynamic>> athletes = [];
  bool get hasMultipleAthletes => athletes.length > 1;

  /// The currently-selected athlete id. Retained across [load] so a manual
  /// selection survives refreshes; falls back to the first athlete.
  String? _selectedAthleteId;
  String? get selectedAthleteId => _selectedAthleteId;

  bool _acting = false;
  bool get acting => _acting; // a decline is in flight

  bool get hasGoal => goal != null;

  String get outcomeText => (goal?['outcomeText'] ?? '').toString();

  /// The AI-formulated headline for the Plan hero, falling back to the parent's
  /// verbatim outcome when a goal has no stored headline.
  String get headline {
    final h = (goal?['headline'] ?? '').toString().trim();
    return h.isNotEmpty ? h : outcomeText;
  }
  String? get targetDate => goal?['targetDate']?.toString();
  String get athleteFirstName {
    final n = (athlete?['firstName'] ?? athlete?['fullName'] ?? '')
        .toString()
        .trim();
    return n.isEmpty ? 'Your athlete' : n.split(' ').first;
  }

  String get athleteId => athlete?['_id']?.toString() ?? '';
  String get planId => plan?['_id']?.toString() ?? '';
  String? get conciergeNote {
    final n = plan?['conciergeNote']?.toString();
    return (n == null || n.trim().isEmpty) ? null : n;
  }

  // Phase progress derived honestly from the plan's phases + current index.
  List<String> get phaseNames {
    final phases = plan?['phases'];
    if (phases is! List) return const [];
    return phases
        .map((p) => (p is Map ? (p['name'] ?? '') : p).toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  int get currentPhaseIndex {
    final i = plan?['currentPhaseIndex'];
    return i is int ? i : 0;
  }

  /// The top `proposed` proposal (rank 0) — drives the "Now" card when there is
  /// no upcoming booked session yet.
  Map<String, dynamic>? get topProposal =>
      proposals.isEmpty ? null : proposals.first;

  Future<void> load() async {
    _loading = true;
    error = null;
    notifyListeners();
    try {
      final loaded = await _repo.getAthletes();
      athletes = loaded
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
      if (athletes.isEmpty) {
        athlete = null;
        _selectedAthleteId = null;
        goal = null;
        plan = null;
        proposals = [];
        digest = null;
        nextBooking = null;
        return;
      }
      // Keep the manual selection when it still exists, else default to first.
      athlete = athletes.firstWhere(
        (a) => a['_id']?.toString() == _selectedAthleteId,
        orElse: () => athletes.first,
      );
      _selectedAthleteId = athlete?['_id']?.toString();
      final aid = athleteId;
      goal = await _repo.getActiveGoal(aid);
      if (goal == null) {
        plan = null;
        proposals = [];
        digest = null;
        nextBooking = null;
        return;
      }
      plan = await _repo.getPlanForGoal(goal!['_id'].toString());
      if (plan != null) {
        final pid = plan!['_id'].toString();
        // Prompt 5: cheap + idempotent; writes a digest / adapts only when the
        // server-side thresholds are met. Non-fatal on error.
        await _repo.planProgress(pid);
        proposals = await _repo.getProposals(pid);
        digest = await _repo.getLatestDigest(pid);
      } else {
        proposals = [];
        digest = null;
      }
      await _loadNextBooking(aid);
    } catch (e) {
      error = 'Could not load your plan. Pull to retry.';
      debugPrint('PlanProvider.load failed: $e');
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
  }

  /// Switch the active athlete (§11). No-ops when already selected or mid-load;
  /// otherwise reloads that athlete's goal / plan / proposals / digest.
  Future<void> selectAthlete(String id) async {
    if (id.isEmpty || id == _selectedAthleteId || _loading) return;
    _selectedAthleteId = id;
    await load();
  }

  Future<void> _loadNextBooking(String athleteId) async {
    try {
      final bookings = await _repo.getBookings();
      final now = DateTime.now();
      Map<String, dynamic>? soonest;
      DateTime? soonestStart;
      for (final b in bookings) {
        if (b is! Map) continue;
        final aid = _bookingAthleteId(b);
        if (aid != null && athleteId.isNotEmpty && aid != athleteId) continue;
        final status = (b['status'] ?? '').toString().toLowerCase();
        if (status == 'declined' || status == 'cancelled') continue;
        final start = _bookingStart(b);
        if (start == null) continue;
        // Keep sessions that haven't clearly passed (small grace window).
        if (start.isBefore(now.subtract(const Duration(hours: 2)))) continue;
        if (soonestStart == null || start.isBefore(soonestStart)) {
          soonestStart = start;
          soonest = Map<String, dynamic>.from(b);
        }
      }
      nextBooking = soonest;
    } catch (e) {
      debugPrint('PlanProvider._loadNextBooking failed: $e');
      nextBooking = null;
    }
  }

  String? _bookingAthleteId(Map b) {
    final a = b['athleteId'];
    if (a is Map) return (a['_id'] ?? a['id'])?.toString();
    return a?.toString();
  }

  DateTime? _bookingStart(Map b) {
    final s = b['sessionId'];
    if (s is Map) return parseSessionStart(s);
    return null;
  }

  /// Parent DECLINES a proposal: flip status (status-only per RLS), then ask the
  /// engine to backfill a replacement, then refresh.
  Future<void> decline(String proposalId) async {
    if (_acting) return;
    _acting = true;
    notifyListeners();
    try {
      final ok = await _repo.updateProposalStatus(proposalId, 'declined');
      if (ok && plan != null) {
        await _repo.generateProposals(plan!['_id'].toString());
      }
    } catch (e) {
      debugPrint('PlanProvider.decline failed: $e');
    } finally {
      _acting = false;
      // Full reload picks up the backfilled proposal + any digest change.
      await load();
    }
  }

  // ── Grounded display helpers (facts come only from DB rows) ────────────────

  /// Distance (km) from the goal's constraints origin to a joined program, or
  /// null when coordinates are missing. Uses the Chicago default when the goal
  /// didn't pin a location (matches how the engine grounded the supply).
  double? distanceKmForProgram(Map? program) {
    if (program == null) return null;
    final loc = program['location'];
    if (loc is! Map) return null;
    final coords = loc['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final plng = (coords[0] as num?)?.toDouble();
    final plat = (coords[1] as num?)?.toDouble();
    if (plat == null || plng == null) return null;
    if (plat == 0 && plng == 0) return null;
    double olat = 41.8781, olng = -87.6298;
    final c = goal?['constraints'];
    if (c is Map) {
      olat = (c['lat'] as num?)?.toDouble() ?? olat;
      olng = (c['lng'] as num?)?.toDouble() ?? olng;
    }
    return _haversineKm(olat, olng, plat, plng);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * (math.pi / 180.0);
}
