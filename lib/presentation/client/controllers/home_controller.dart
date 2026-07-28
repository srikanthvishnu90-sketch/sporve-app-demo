import 'package:flutter/material.dart';
import '../view/search_screen.dart'; // To access Opportunity model
import '../../../core/data/app_repository.dart';
import '../../../core/utils/session_time.dart';

class HomeProvider with ChangeNotifier {
  final AppRepository _repo;
  HomeProvider(this._repo);

  // User Profile State
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool _isLoadingProfile = false;
  bool get isLoadingProfile => _isLoadingProfile;

  // Stats State — all derived from real data (see _calculateStats).
  Map<String, dynamic> _stats = {'sessions': 0, 'upcoming': 0, 'saved': 0};
  Map<String, dynamic> get stats => _stats;

  // Programs State
  List<dynamic> _programs = [];
  List<dynamic> get programs => _programs;
  bool _isLoadingPrograms = false;
  bool get isLoadingPrograms => _isLoadingPrograms;
  bool _programsError = false;
  bool get programsError =>
      _programsError; // true = the last load FAILED (not empty)

  // Bookings State
  List<dynamic> _bookings = [];
  List<dynamic> get bookings => _bookings;
  bool _isLoadingBookings = false;
  bool get isLoadingBookings => _isLoadingBookings;

  // Sessions cache — powers the "next available" line + "Available this week"
  // section on Explore. Grounded in the real sessions table.
  List<dynamic> _sessions = [];
  List<dynamic> get sessions => _sessions;

  // Past Searches
  final List<String> _pastSearches = [];
  List<String> get pastSearches => _pastSearches;

  void addPastSearch(String query) {
    if (!_pastSearches.contains(query)) {
      _pastSearches.insert(0, query);
      if (_pastSearches.length > 5) _pastSearches.removeLast();
      notifyListeners();
    }
  }

  // Athletes (children) belonging to the signed-in searcher.
  List<dynamic> _athletes = [];
  List<dynamic> get athletes => _athletes;

  Future<void> fetchAllAthleteData() async {
    await Future.wait([
      fetchUserProfile(),
      fetchPrograms(),
      fetchBookings(),
      fetchFavorites(),
      fetchAthletes(),
      fetchSessions(),
    ]);
    _calculateStats();
  }

  Future<void> fetchSessions() async {
    try {
      _sessions = await _repo.getSessions();
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
    }
  }

  /// Soonest upcoming (today or later) session start for [programId], or null.
  /// Read synchronously off the [sessions] cache so Explore cards can show a
  /// grounded "next available" line without a per-card async call.
  DateTime? nextSessionStartForProgram(String? programId) {
    if (programId == null || programId.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? soonest;
    for (final s in _sessions) {
      if (s is! Map) continue;
      final sProg = s['programId'];
      final pid = sProg is Map ? sProg['_id']?.toString() : sProg?.toString();
      if (pid != programId) continue;
      final start = parseSessionStart(s);
      final day = DateTime(start.year, start.month, start.day);
      if (day.isBefore(today)) continue;
      if (soonest == null || start.isBefore(soonest)) soonest = start;
    }
    return soonest;
  }

  Future<void> fetchAthletes() async {
    try {
      _athletes = await _repo.getAthletes();
    } catch (e) {
      debugPrint('Error fetching athletes: $e');
    }
  }

  /// Adds a child for the signed-in parent, refreshes the list, and returns the
  /// new id (null on failure). Powers the in-app "Add child" flow so booking
  /// never dead-ends on an empty profile.
  Future<String?> addAthlete({
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? gender,
    String? skillLevel,
  }) async {
    final id = await _repo.addAthlete({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'dateOfBirth': ?dateOfBirth,
      'gender': ?gender,
      'skillLevel': ?skillLevel,
    });
    if (id != null) {
      await fetchAthletes();
      notifyListeners();
    }
    return id;
  }

  /// Real upcoming sessions for a program (today or later, soonest first).
  Future<List<dynamic>> sessionsForProgram(String? programId) async {
    if (programId == null || programId.isEmpty) return [];
    try {
      final all = await _repo.getSessions();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final list = all.where((s) {
        if (s is! Map) return false;
        final sProg = s['programId'];
        final pid = sProg is Map ? sProg['_id']?.toString() : sProg?.toString();
        if (pid != programId) return false;
        final start = parseSessionStart(s);
        final day = DateTime(start.year, start.month, start.day);
        return !day.isBefore(today);
      }).toList();
      list.sort((a, b) => parseSessionStart(a).compareTo(parseSessionStart(b)));
      return list;
    } catch (e) {
      debugPrint('Error fetching sessions for program: $e');
      return [];
    }
  }

  /// Bookable trainers of a given organization, for the athlete-side picker.
  /// Returns only verified + active members (RLS/mock both enforce it), so an
  /// empty list means "solo provider / no roster" and the picker is hidden.
  Future<List<Map<String, dynamic>>> trainersForProvider(String? orgId) async {
    if (orgId == null || orgId.isEmpty) return [];
    try {
      return await _repo.getOrgMembersForProvider(orgId);
    } catch (e) {
      debugPrint('trainersForProvider failed: $e');
      return [];
    }
  }

  /// Count of bookings whose session starts today or later.
  int get _upcomingCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var n = 0;
    for (final b in _bookings) {
      if (b is! Map) continue;
      final session = b['sessionId'] is Map ? b['sessionId'] : null;
      final start = parseSessionStart(session);
      final day = DateTime(start.year, start.month, start.day);
      if (!day.isBefore(today)) n++;
    }
    return n;
  }

  void _calculateStats() {
    _stats = {
      'sessions': _bookings.length, // total bookings made
      'upcoming': _upcomingCount, // bookings still in the future
      'saved': _favoriteIds.length, // favorited programs
    };
    notifyListeners();
  }

  /// Merges [updates] into the profile, persists, and refreshes the UI.
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    final merged = <String, dynamic>{...?_userProfile, ...updates};
    await _repo.saveUserProfile(merged);
    _userProfile = merged;
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    _isLoadingProfile = true;
    notifyListeners();
    await Future.delayed(
      const Duration(milliseconds: 200),
    ); // Simulate UI loading state
    try {
      _userProfile = await _repo.getUserProfile();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> fetchPrograms() async {
    _isLoadingPrograms = true;
    _programsError = false;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      _programs = await _repo.getProgramsOrThrow();
    } catch (e) {
      // Real failure (network/server) — surface it so the UI offers a retry
      // instead of rendering a misleading "no programs" empty state.
      debugPrint('Error fetching programs: $e');
      _programsError = true;
    } finally {
      _isLoadingPrograms = false;
      notifyListeners();
    }
  }

  Future<void> fetchBookings() async {
    _isLoadingBookings = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      _bookings = await _repo.getBookings();
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
    } finally {
      _isLoadingBookings = false;
      notifyListeners();
    }
  }

  /// Persist a new booking and refresh derived state so Home + Schedule update.
  /// Returns the new booking's id (null if it couldn't be created).
  Future<String?> addBooking(Map<String, dynamic> booking) async {
    final id = await _repo.addBooking(booking);
    _bookings = await _repo.getBookings();
    _calculateStats(); // also calls notifyListeners()
    return id;
  }

  /// Marks a booking paid + confirmed (the offline-demo equivalent of a
  /// successful Stripe checkout) and persists it, so it lands on Schedule/Home
  /// as a real confirmed session.
  Future<void> markBookingPaid(String bookingId) async {
    _bookings = _bookings.map((b) {
      final id = (b is Map) ? (b['_id'] ?? b['id'])?.toString() : null;
      if (id == bookingId && b is Map) {
        final m = Map<String, dynamic>.from(b);
        m['paymentStatus'] = 'paid';
        m['status'] = 'confirmed';
        return m;
      }
      return b;
    }).toList();
    await _repo.saveBookings(_bookings);
    _calculateStats(); // also notifies
  }

  /// Cancels a booking: persists status='cancelled' and drops it from the
  /// active list so it leaves Schedule + "Coming Up" immediately.
  Future<bool> cancelBooking(String bookingId) async {
    final ok = await _repo.updateBookingStatus(bookingId, 'cancelled');
    if (!ok) return false;
    _bookings = _bookings.where((b) {
      final id = (b is Map) ? (b['_id'] ?? b['id'])?.toString() : null;
      return id != bookingId;
    }).toList();
    _calculateStats(); // also calls notifyListeners()
    return true;
  }

  /// The booking with [id] from the latest fetched list, or null.
  Map<String, dynamic>? bookingById(String? id) {
    if (id == null) return null;
    for (final b in _bookings) {
      if (b is Map && b['_id']?.toString() == id) {
        return Map<String, dynamic>.from(b);
      }
    }
    return null;
  }

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  // Favorites are keyed by the REAL program id and persisted via the repository.
  Set<String> _favoriteIds = {};
  Set<String> get favoriteIds => _favoriteIds;

  final String _athleteTeam = 'ScoreNow Elite';
  String get athleteTeam => _athleteTeam;

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> fetchFavorites() async {
    try {
      _favoriteIds = (await _repo.getFavorites()).toSet();
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
    }
  }

  bool isFavorite(String? programId) =>
      programId != null &&
      programId.isNotEmpty &&
      _favoriteIds.contains(programId);

  Future<void> toggleFavorite(String? programId) async {
    if (programId == null || programId.isEmpty) return;
    if (_favoriteIds.contains(programId)) {
      _favoriteIds.remove(programId);
    } else {
      _favoriteIds.add(programId);
    }
    await _repo.saveFavorites(_favoriteIds.toList());
    _calculateStats(); // refresh "saved" + notifyListeners()
  }

  // Clear search history
  void clearPastSearches() {
    _pastSearches.clear();
    notifyListeners();
  }

  // Dynamic recommendation scoring algorithm
  List<Opportunity> getRecommendations(List<Opportunity> allOpportunities) {
    if (allOpportunities.isEmpty) return [];

    final Map<int, double> scores = {};

    for (var opp in allOpportunities) {
      double score = 0.0;

      // 1. Team Association Match (High Priority)
      if (opp.team.toLowerCase() == _athleteTeam.toLowerCase()) {
        score += 10.0;
      }

      // 2. Past Search Match (Keyword Match Boost)
      for (var search in _pastSearches) {
        final cleanSearch = search.toLowerCase().trim();
        if (cleanSearch.isEmpty) continue;

        if (opp.title.toLowerCase().contains(cleanSearch)) {
          score += 5.0;
        }
        if (opp.coach.toLowerCase().contains(cleanSearch)) {
          score += 3.0;
        }
        if (opp.team.toLowerCase().contains(cleanSearch)) {
          score += 2.0;
        }
      }

      scores[opp.id] = score;
    }

    // Sort opportunities descending by score
    final List<Opportunity> sorted = List.from(allOpportunities);
    sorted.sort((a, b) {
      final scoreA = scores[a.id] ?? 0.0;
      final scoreB = scores[b.id] ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    return sorted.take(3).toList();
  }
}
