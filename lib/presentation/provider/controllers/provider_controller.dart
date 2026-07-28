import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/app_repository.dart';
import '../../../core/theme/app_colors.dart';

class ProviderListing {
  // ── Server identity ──────────────────────────────────────────────
  String id; // backend _id

  // ── Core fields ──────────────────────────────────────────────────
  String image;
  String title;
  String description;
  String sportType;
  String programType; // Training | Camp | Clinic | League | AAU | Private | ...
  String skillLevel;
  String ageGroup;
  String language;
  double price;
  String currency;
  String pricingModel;
  int maxCapacity;
  int enrolledCount;
  List<String> gallery;
  List<String> whatsIncluded;

  // ── Location / address ───────────────────────────────────────────
  List<double> coordinates;
  String addressLine1;
  String city;
  String state;
  String zip;
  String country;

  // ── Policy / meta ────────────────────────────────────────────────
  String cancellationPolicy;
  int minimumAge;
  int maximumAge;
  bool isFeatured;
  String status; // 'published' | 'draft' | etc.

  // ── Provider info (populated from detail response) ────────────────
  String providerName;
  bool providerVerified;

  // ── Stats ────────────────────────────────────────────────────────
  double averageRating;
  int totalReviews;

  // ── Detail-loaded flag ───────────────────────────────────────────
  bool detailsLoaded;

  // ── Sessions for this program listing ─────────────────────────────
  List<Map<String, dynamic>> sessions = [];

  // ── UI helpers ───────────────────────────────────────────────────
  IconData get sportIconData {
    if (sportType == 'Soccer') return Icons.sports_soccer;
    if (sportType == 'Basketball') return Icons.sports_basketball;
    if (sportType == 'Football') return Icons.sports_football;
    if (sportType == 'Swimming') return Icons.pool;
    if (sportType == 'Tennis') return Icons.sports_tennis;
    return Icons.sports;
  }

  String get sportIcon {
    if (sportType == 'Soccer') return '⚽';
    if (sportType == 'Basketball') return '🏀';
    if (sportType == 'Football') return '🏈';
    if (sportType == 'Swimming') return '🏊';
    if (sportType == 'Tennis') return '🎾';
    return '🏃';
  }

  String get category {
    if (pricingModel == 'single_session') return 'TRAINING';
    if (pricingModel == 'monthly') return 'PROGRAMS';
    return 'CAMPS';
  }

  String get rating =>
      averageRating > 0 ? averageRating.toStringAsFixed(1) : '0.0';
  String get availability {
    final spots = maxCapacity - enrolledCount;
    if (spots <= 0) return 'FULL';
    if (spots <= 3) return '$spots SPOTS LEFT';
    return 'AVAILABLE NOW';
  }

  Color get availabilityColor {
    final spots = maxCapacity - enrolledCount;
    if (spots <= 0) return AppColors.negative;
    if (spots <= 3) return AppColors.warning;
    return AppColors.slateText;
  }

  ProviderListing({
    this.id = '',
    required this.image,
    required this.title,
    required this.description,
    required this.sportType,
    this.programType = 'Training',
    required this.skillLevel,
    required this.ageGroup,
    required this.language,
    required this.price,
    this.currency = 'USD',
    required this.pricingModel,
    required this.maxCapacity,
    this.enrolledCount = 0,
    this.gallery = const [],
    this.whatsIncluded = const [],
    required this.coordinates,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
    required this.cancellationPolicy,
    required this.minimumAge,
    required this.maximumAge,
    this.isFeatured = false,
    this.status = 'published',
    this.providerName = '',
    this.providerVerified = false,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.detailsLoaded = false,
  });

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'coverImage': image,
      'title': title,
      'description': description,
      'sportType': sportType,
      'programType': programType,
      'skillLevel': skillLevel,
      'ageGroup': ageGroup,
      'language': language,
      'price': price,
      'currency': currency,
      'pricingModel': pricingModel,
      'maxCapacity': maxCapacity,
      'enrolledCount': enrolledCount,
      'location': {'type': 'Point', 'coordinates': coordinates},
      'address': {
        'line1': addressLine1,
        'city': city,
        'state': state,
        'zip': zip,
        'country': country,
      },
      'cancellationPolicy': cancellationPolicy,
      'minimumAge': minimumAge,
      'maximumAge': maximumAge,
      'isFeatured': isFeatured,
      'status': status,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'providerId': {
        'businessName': providerName,
        'verificationStatus': providerVerified ? 'verified' : 'unverified',
      },
    };
  }

  /// Merge full detail data (from GET /programs/:id) into this listing.
  void applyDetails(Map<String, dynamic> data) {
    final loc = data['location']?['coordinates'];
    final addr = data['address'] ?? {};
    final prov = data['providerId'];

    image = data['coverImage'] ?? image;
    title = data['title'] ?? title;
    description = data['description'] ?? description;
    sportType = data['sportType'] ?? sportType;
    skillLevel = data['skillLevel'] ?? skillLevel;
    ageGroup = data['ageGroup'] ?? ageGroup;
    language = data['language'] ?? language;
    price = (data['price'] as num?)?.toDouble() ?? price;
    currency = data['currency'] ?? currency;
    pricingModel = data['pricingModel'] ?? pricingModel;
    maxCapacity = (data['maxCapacity'] as num?)?.toInt() ?? maxCapacity;
    enrolledCount = (data['enrolledCount'] as num?)?.toInt() ?? enrolledCount;
    isFeatured = data['isFeatured'] ?? isFeatured;
    status = data['status'] ?? status;
    averageRating =
        (data['averageRating'] as num?)?.toDouble() ?? averageRating;
    totalReviews = (data['totalReviews'] as num?)?.toInt() ?? totalReviews;
    cancellationPolicy = data['cancellationPolicy'] ?? cancellationPolicy;
    minimumAge = (data['minimumAge'] as num?)?.toInt() ?? minimumAge;
    maximumAge = (data['maximumAge'] as num?)?.toInt() ?? maximumAge;

    if (loc != null && loc.length >= 2) {
      coordinates = [loc[0].toDouble(), loc[1].toDouble()];
    }
    addressLine1 = addr['line1'] ?? addressLine1;
    city = addr['city'] ?? city;
    state = addr['state'] ?? state;
    zip = addr['zip'] ?? zip;
    country = addr['country'] ?? country;

    if (prov is Map) {
      providerName = prov['businessName']?.toString() ?? providerName;
      providerVerified = prov['verificationStatus'] == 'verified';
    }

    final rawGallery = data['gallery'];
    if (rawGallery is List) gallery = List<String>.from(rawGallery);

    final rawIncluded = data['whatsIncluded'];
    if (rawIncluded is List) whatsIncluded = List<String>.from(rawIncluded);

    detailsLoaded = true;
  }
}

class ScheduledSession {
  final String id;
  final String userName;
  final String userAvatar;
  final String serviceTitle;
  final DateTime sessionDate; // Date of the session
  final String timeStr; // Time e.g. "5:00 PM"
  bool isConfirmed;
  bool isDeclined;
  bool isCompleted;
  bool isNoShow;
  // Context for the "Write parent update" flow (from the booking).
  final String childId;
  final String childFirstName;
  final String sport;

  ScheduledSession({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.serviceTitle,
    required this.sessionDate,
    required this.timeStr,
    this.isConfirmed = false,
    this.isDeclined = false,
    this.isCompleted = false,
    this.isNoShow = false,
    this.childId = '',
    this.childFirstName = '',
    this.sport = '',
  });
}

class CoachTeam {
  final String id;
  final String name;

  const CoachTeam({required this.id, required this.name});
}

class ProviderController with ChangeNotifier {
  final AppRepository _repo;
  ProviderController(this._repo);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Listings State — loaded from API
  final List<ProviderListing> _listings = [];
  bool _listingsLoaded = false;
  bool _listingsError = false;
  bool _bookingsError = false;

  List<ProviderListing> get listings => _listings;
  bool get listingsLoaded => _listingsLoaded;
  bool get listingsError => _listingsError; // last listings load FAILED
  bool get bookingsError => _bookingsError; // last bookings load FAILED

  // ── Roster: affiliated trainers (Booksy model) ────────────────────────────
  final List<Map<String, dynamic>> _trainers = [];
  bool _trainersLoaded = false;
  List<Map<String, dynamic>> get trainers => List.unmodifiable(_trainers);
  bool get trainersLoaded => _trainersLoaded;

  /// Monthly revenue the org keeps from its trainers' commissions (from booking
  /// snapshots, this month). Wired to real bookings in the payments phase.
  double get monthlyTrainerRevenue => _monthlyTrainerRevenue;
  final double _monthlyTrainerRevenue = 0;

  Future<void> loadTrainers() async {
    try {
      final rows = await _repo.getOrgMembers();
      _trainers
        ..clear()
        ..addAll(rows);
    } catch (_) {/* keep whatever we had */}
    _trainersLoaded = true;
    notifyListeners();
  }

  Future<bool> createTrainer(Map<String, dynamic> member) async {
    final id = await _repo.createOrgMember(member);
    if (id == null) return false;
    _trainers.insert(0, {...member, 'id': id, 'background_check_status': 'none'});
    notifyListeners();
    return true;
  }

  Future<bool> updateTrainer(String id, Map<String, dynamic> patch) async {
    final ok = await _repo.updateOrgMember(id, patch);
    if (ok) {
      final i = _trainers.indexWhere((m) => m['id'] == id);
      if (i >= 0) _trainers[i] = {..._trainers[i], ...patch};
      notifyListeners();
    }
    return ok;
  }

  Future<bool> deleteTrainer(String id) async {
    final ok = await _repo.deleteOrgMember(id);
    if (ok) {
      _trainers.removeWhere((m) => m['id'] == id);
      notifyListeners();
    }
    return ok;
  }

  // Provider profile (incl. Stripe payouts status) — loaded from the data layer.
  Map<String, dynamic> _providerProfile = {};
  Map<String, dynamic> get providerProfile => _providerProfile;
  String? get stripeAccountId => _providerProfile['stripeAccountId'] as String?;
  bool get stripeChargesEnabled =>
      _providerProfile['stripeChargesEnabled'] == true;

  /// Re-fetch the provider so the payouts status reflects stripe_charges_enabled
  /// (the #20c webhook keeps this fresh automatically once it lands).
  Future<void> fetchProviderProfile() async {
    try {
      _providerProfile = await _repo.getProviderProfile();
    } catch (_) {
      /* leave prior value; UI shows setup state */
    }
    notifyListeners();
  }

  // ── Account (profiles) + save plumbing for the profile/settings screens ──
  Map<String, dynamic> _accountProfile = {};
  Map<String, dynamic> get accountProfile => _accountProfile;
  bool _savingProfile = false;
  bool get savingProfile => _savingProfile;
  String? _profileError;
  String? get profileError => _profileError;

  Future<void> fetchAccountProfile() async {
    try {
      _accountProfile = await _repo.getUserProfile();
    } catch (e) {
      debugPrint('fetchAccountProfile failed: $e');
    }
    notifyListeners();
  }

  /// Persist account (profiles) fields. Returns false + sets [profileError] on
  /// failure so the screen can show a REAL error (never a fake "Saved!").
  Future<bool> saveMyAccount(Map<String, dynamic> updates) async {
    _savingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      await _repo.saveUserProfile(updates);
      _accountProfile = await _repo.getUserProfile();
      return true;
    } catch (e) {
      _profileError = 'Could not save your profile. Please try again.';
      debugPrint('saveMyAccount failed: $e');
      return false;
    } finally {
      _savingProfile = false;
      notifyListeners();
    }
  }

  /// Persist provider (business) fields. Returns false + sets [profileError].
  Future<bool> saveMyProvider(Map<String, dynamic> updates) async {
    _savingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      await _repo.saveProviderProfile(updates);
      _providerProfile = await _repo.getProviderProfile();
      // On profile create/update, refresh this provider's listing embeddings so
      // search reflects the new bio/specialties/session descriptions. Best-effort
      // and idempotent: backfill-embeddings skips rows whose source hash is
      // unchanged, so an unchanged save does not re-embed. Never blocks the save.
      try {
        await Supabase.instance.client.functions.invoke('backfill-embeddings');
      } catch (e) {
        debugPrint('embedding refresh skipped: $e');
      }
      return true;
    } catch (e) {
      _profileError = 'Could not save your business profile. Please try again.';
      debugPrint('saveMyProvider failed: $e');
      return false;
    } finally {
      _savingProfile = false;
      notifyListeners();
    }
  }

  /// Fetches the authenticated provider's programs from the server.
  /// After building the basic list from the /provider/me endpoint,
  /// it calls GET /programs/:id for every listing to hydrate the
  /// full detail data (provider info, gallery, ratings, etc.).
  Future<void> fetchMyPrograms() async {
    _setLoading(true);
    _listingsError = false;
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final data = await _repo.getProgramsOrThrow();
      // Scope "my listings" to the authenticated provider's own business so the
      // provider view shows exactly its 5 listings, not every business's.
      if (_providerProfile.isEmpty) {
        try {
          _providerProfile = await _repo.getProviderProfile();
        } catch (_) {}
      }
      final myBiz = (_providerProfile['businessName'] ?? '').toString().trim();
      _listings.clear();
      for (final item in data) {
        try {
          final loc = item['location']?['coordinates'];
          final addr = item['address'] ?? {};
          final prov = item['providerId'];
          final biz = (prov is Map ? prov['businessName']?.toString() : '') ?? '';
          if (myBiz.isNotEmpty && biz != myBiz) continue;
          _listings.add(
            ProviderListing(
              id: item['_id']?.toString() ?? '',
              image: item['coverImage'] ?? '',
              title: item['title'] ?? '',
              description: item['description'] ?? '',
              sportType: item['sportType'] ?? '',
              programType: item['programType'] ?? 'Training',
              skillLevel: item['skillLevel'] ?? '',
              ageGroup: item['ageGroup'] ?? '',
              language: item['language'] ?? 'English',
              price: (item['price'] as num?)?.toDouble() ?? 0,
              currency: item['currency'] ?? 'USD',
              pricingModel: item['pricingModel'] ?? 'single_session',
              maxCapacity: (item['maxCapacity'] as num?)?.toInt() ?? 0,
              enrolledCount: (item['enrolledCount'] as num?)?.toInt() ?? 0,
              coordinates: loc != null
                  ? [loc[0].toDouble(), loc[1].toDouble()]
                  : [0.0, 0.0],
              addressLine1: addr['line1'] ?? addr['addressLine1'] ?? '',
              city: addr['city'] ?? '',
              state: addr['state'] ?? '',
              zip: addr['zip'] ?? addr['zipCode'] ?? '',
              country: addr['country'] ?? '',
              cancellationPolicy: item['cancellationPolicy'] ?? 'flexible',
              minimumAge: (item['minimumAge'] as num?)?.toInt() ?? 0,
              maximumAge: (item['maximumAge'] as num?)?.toInt() ?? 99,
              isFeatured: item['isFeatured'] ?? false,
              status: item['status'] ?? 'published',
              averageRating: (item['averageRating'] as num?)?.toDouble() ?? 0.0,
              totalReviews: (item['totalReviews'] as num?)?.toInt() ?? 0,
              providerName: (prov is Map)
                  ? (prov['businessName']?.toString() ?? '')
                  : '',
              providerVerified:
                  (prov is Map) && prov['verificationStatus'] == 'verified',
            ),
          );
        } catch (_) {}
      }
      notifyListeners();
      await _fetchAllDetails();
    } catch (e) {
      debugPrint('fetchMyPrograms failed: $e');
      _listingsError = true;
    } finally {
      _listingsLoaded = true;
      _setLoading(false);
    }
  }

  Future<void> _fetchAllDetails() async {
    // Details already populated from mock data
  }

  Future<void> fetchProgramDetails(String programId) async {
    // Details already populated from mock data
  }

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<bool> createProgram(
    ProviderListing listing, {
    List<String>? galleryPaths,
  }) async {
    _setLoading(true);
    _lastErrorMessage = null;
    // Real INSERT that returns the program's id and seeds bookable sessions, so
    // a brand-new listing is immediately bookable (was: list-replace, no id, no
    // sessions -> "no upcoming sessions for this program").
    final id = await _repo.createProgram(listing.toJson());
    if (id == null) {
      _lastErrorMessage = 'Could not create the program. Please try again.';
      _setLoading(false);
      notifyListeners();
      return false;
    }
    listing.id = id;
    _listings.insert(0, listing);
    _setLoading(false);
    notifyListeners();
    return true;
  }

  /// Insert or update a program in persistent storage, matched by `_id`.
  Future<void> _syncProgramToMock(ProviderListing listing) async {
    if (listing.id.isEmpty) return;
    final progs = List<dynamic>.from(await _repo.getPrograms());
    final idx = progs.indexWhere(
      (p) => p is Map && p['_id']?.toString() == listing.id,
    );
    if (idx >= 0) {
      progs[idx] = listing.toJson();
    } else {
      progs.insert(0, listing.toJson());
    }
    await _repo.savePrograms(progs);
  }

  void addListing(ProviderListing listing) {
    _listings.add(listing);
    notifyListeners();
  }

  Future<bool> editProgram(
    int index,
    ProviderListing listing, {
    List<String>? galleryPaths,
  }) async {
    if (index < 0 || index >= _listings.length) return false;
    _setLoading(true);
    _lastErrorMessage = null;
    await Future.delayed(const Duration(milliseconds: 300));
    // Preserve the original id so the edit updates the right stored program.
    if (listing.id.isEmpty) listing.id = _listings[index].id;
    _listings[index] = listing;
    await _syncProgramToMock(listing);
    _setLoading(false);
    notifyListeners();
    return true;
  }

  void updateListing(int index, ProviderListing listing) {
    if (index >= 0 && index < _listings.length) {
      _listings[index] = listing;
      notifyListeners();
    }
  }

  Future<void> deleteListing(int index) async {
    if (index >= 0 && index < _listings.length) {
      final id = _listings[index].id;
      _listings.removeAt(index);
      // Remove from persistent storage too so it doesn't reappear on refresh.
      if (id.isNotEmpty) {
        final progs = List<dynamic>.from(await _repo.getPrograms());
        progs.removeWhere((p) => p is Map && p['_id']?.toString() == id);
        await _repo.savePrograms(progs);
      }
      notifyListeners();
    }
  }

  // Schedule State
  DateTime _selectedDate = DateTime(
    2026,
    5,
    4,
  ); // Default to Monday, May 4, 2026
  DateTime _currentMonth = DateTime(2026, 5, 1);

  DateTime get selectedDate => _selectedDate;
  DateTime get currentMonth => _currentMonth;

  final List<ScheduledSession> _sessions = [];

  List<ScheduledSession> get sessions => _sessions;

  List<ScheduledSession> getSessionsForDate(DateTime date) {
    return _sessions.where((session) {
      return session.sessionDate.year == date.year &&
          session.sessionDate.month == date.month &&
          session.sessionDate.day == date.day &&
          !session.isDeclined;
    }).toList();
  }

  bool hasSessionsOnDate(DateTime date) {
    return _sessions.any((session) {
      return session.sessionDate.year == date.year &&
          session.sessionDate.month == date.month &&
          session.sessionDate.day == date.day &&
          !session.isDeclined;
    });
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void nextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    notifyListeners();
  }

  void prevMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    notifyListeners();
  }

  // ── Booking lifecycle: persist the status transition, then reflect locally.
  // The DB trigger reacts (booking_confirmed / post_session / no_show_followup).
  Future<bool> confirmSession(String sessionId) =>
      _setStatus(sessionId, 'confirmed');
  Future<bool> declineSession(String sessionId) =>
      _setStatus(sessionId, 'declined');
  Future<bool> completeSession(String sessionId) =>
      _setStatus(sessionId, 'completed');
  Future<bool> markNoShow(String sessionId) => _setStatus(sessionId, 'no_show');

  Future<bool> _setStatus(String sessionId, String status) async {
    // Mock sessions (req_/conf_/other_) have no DB row — flip locally only.
    final isMock =
        sessionId.startsWith('req_') ||
        sessionId.startsWith('conf_') ||
        sessionId.startsWith('other_');
    final ok = isMock
        ? true
        : await _repo.updateBookingStatus(sessionId, status);
    if (!ok) return false;
    final i = _sessions.indexWhere((s) => s.id == sessionId);
    if (i != -1) {
      final s = _sessions[i];
      s.isConfirmed = status == 'confirmed' || status == 'completed';
      s.isDeclined = status == 'declined';
      s.isCompleted = status == 'completed';
      s.isNoShow = status == 'no_show';
      notifyListeners();
    }
    return true;
  }

  bool _bookingsLoaded = false;
  bool get bookingsLoaded => _bookingsLoaded;

  // Real dashboard metrics derived from the provider's bookings/listings.
  double _revenue = 0; // sum of PAID bookings' final price
  double get revenue => _revenue;

  // ── Payouts + roster broadcasts (demo ledger — persists in memory) ──────
  double _withdrawn = 0;
  double get availableBalance {
    final v = _revenue - _withdrawn;
    return v < 0 ? 0 : v;
  }

  final List<Map<String, dynamic>> _withdrawals = [];
  List<Map<String, dynamic>> get withdrawals => List.unmodifiable(_withdrawals);

  /// Records a payout request (demo: no real bank rail). Returns false for a
  /// non-positive amount.
  bool recordWithdrawal(double amount) {
    if (amount <= 0) return false;
    _withdrawn += amount;
    _withdrawals.insert(0, {
      'amount': amount,
      'at': DateTime.now().toIso8601String(),
      'status': 'processing',
    });
    notifyListeners();
    return true;
  }

  final List<String> _broadcasts = [];

  /// Records a roster broadcast and returns the number of athletes it reaches.
  int sendBroadcast(String text) {
    if (text.trim().isEmpty) return 0;
    _broadcasts.add(text.trim());
    notifyListeners();
    return _rosterAthletes.length;
  }
  int get bookingCount => _sessions.where((s) => !s.isDeclined).length;
  int get listingCount => _listings.length;
  int get sessionsToday {
    final now = DateTime.now();
    return _sessions
        .where(
          (s) =>
              !s.isDeclined &&
              s.sessionDate.year == now.year &&
              s.sessionDate.month == now.month &&
              s.sessionDate.day == now.day,
        )
        .length;
  }

  Future<void> fetchProviderBookings() async {
    _setLoading(true);
    _bookingsError = false;
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final data = await _repo.getBookingsOrThrow();
      _sessions.clear();
      _revenue = 0;
      for (final booking in data) {
        try {
          final id = booking['_id']?.toString() ?? '';
          final status = booking['status']?.toString() ?? 'confirmed';
          if ((booking['paymentStatus']?.toString() ?? '') == 'paid') {
            _revenue += (booking['finalPrice'] as num?)?.toDouble() ?? 0;
          }
          final athlete = booking['athleteId'] ?? {};
          final userName = athlete['fullName'] ?? 'Athlete';
          final userAvatar = athlete['profileImage'] ?? '';
          final childId = (athlete['_id'] ?? '').toString();
          final childFirstName =
              (athlete['firstName'] ?? userName.toString().split(' ').first)
                  .toString();

          String serviceTitle = 'Training Session';
          DateTime sessionDate = DateTime.now();
          String timeStr = '12:00 PM';
          String sport = '';

          final sess = booking['sessionId'];
          if (sess is Map) {
            serviceTitle = sess['title'] ?? serviceTitle;
            if (sess['date'] != null) {
              sessionDate = DateTime.tryParse(sess['date']) ?? sessionDate;
            }
            timeStr = sess['startTime'] ?? timeStr;
          }

          final prog = booking['programId'];
          if (prog is Map) {
            serviceTitle = prog['title'] ?? serviceTitle;
            sport = (prog['sport'] ?? '').toString();
          }

          final s = status.toLowerCase();
          final isCompleted = s == 'completed';
          final isNoShow = s == 'no_show';
          final isConfirmed = s == 'confirmed' || s == 'active' || isCompleted;
          final isDeclined = s == 'cancelled' || s == 'declined';

          _sessions.add(
            ScheduledSession(
              id: id,
              userName: userName,
              userAvatar: userAvatar,
              serviceTitle: serviceTitle,
              sessionDate: sessionDate,
              timeStr: timeStr,
              isConfirmed: isConfirmed,
              isDeclined: isDeclined,
              isCompleted: isCompleted,
              isNoShow: isNoShow,
              childId: childId,
              childFirstName: childFirstName,
              sport: sport,
            ),
          );
        } catch (e) {
          debugPrint('Error parsing booking item: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('fetchProviderBookings failed: $e');
      _bookingsError = true;
    } finally {
      _bookingsLoaded = true;
      _setLoading(false);
    }
  }

  // ── Roster & Teams State ─────────────────────────────────────────
  final List<CoachTeam> _rosterTeams = [];
  final List<Map<String, dynamic>> _rosterAthletes = [];
  bool _rosterLoaded = false;

  List<CoachTeam> get rosterTeams => _rosterTeams;
  List<Map<String, dynamic>> get rosterAthletes => _rosterAthletes;
  bool get rosterLoaded => _rosterLoaded;

  Future<void> fetchRosterData() async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final data = await _repo.getTeams();
      _rosterTeams.clear();
      _rosterAthletes.clear();
      _rosterTeams.add(
        const CoachTeam(id: 'unassigned', name: 'Unassigned Athletes'),
      );

      for (final teamItem in data) {
        final teamId = teamItem['_id']?.toString() ?? '';
        final teamName = teamItem['name']?.toString() ?? 'Unnamed Team';
        _rosterTeams.add(CoachTeam(id: teamId, name: teamName));

        final roster = teamItem['roster'];
        if (roster is List) {
          for (final athleteItem in roster) {
            if (athleteItem is Map<String, dynamic>) {
              _rosterAthletes.add({
                'id': athleteItem['_id']?.toString() ?? '',
                'name': athleteItem['fullName']?.toString() ?? 'Athlete',
                'email': athleteItem['email']?.toString() ?? '',
                'jersey': athleteItem['jerseyNumber']?.toString() ?? '#7',
                'imageUrl': athleteItem['avatar'] ?? '',
                'isAvailable': athleteItem['isAvailable'] ?? true,
                'isPaid': athleteItem['isPaid'] ?? true,
                'teamId': teamId,
              });
            }
          }
        }
      }
      notifyListeners();
    } finally {
      _rosterLoaded = true;
      _setLoading(false);
    }
  }

  Future<bool> createRosterTeam(String name, String sport) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 300));
    _rosterTeams.add(
      CoachTeam(
        id: 'team_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
      ),
    );
    _setLoading(false);
    return true;
  }

  Future<bool> moveRosterAthlete(
    String athleteId,
    String sourceTeamId,
    String targetTeamId,
  ) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 300));
    final i = _rosterAthletes.indexWhere((a) => a['id'] == athleteId);
    if (i >= 0) _rosterAthletes[i]['teamId'] = targetTeamId;
    _setLoading(false);
    return true;
  }

  Future<bool> addRosterAthlete(String teamId, String athleteId) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 300));
    final i = _rosterAthletes.indexWhere((a) => a['id'] == athleteId);
    if (i >= 0) _rosterAthletes[i]['teamId'] = teamId;
    _setLoading(false);
    return true;
  }

  Future<bool> removeRosterAthlete(String teamId, String athleteId) async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 300));
    _rosterAthletes.removeWhere((a) => a['id'] == athleteId);
    _setLoading(false);
    return true;
  }

  // ── Program Sessions State & Operations ────────────────────────────
  final List<dynamic> _programSessions = [];
  List<dynamic> get programSessions => _programSessions;
  bool _sessionsLoading = false;
  bool get sessionsLoading => _sessionsLoading;

  Future<void> fetchProgramSessions(String programId) async {
    _sessionsLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final data = await _repo.getSessions();
      _programSessions.clear();
      _programSessions.addAll(data);
    } finally {
      _sessionsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProgramSession(Map<String, dynamic> body) async {
    _sessionsLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    final entry = {
      ...body,
      '_id':
          body['_id']?.toString() ??
          'sess_${DateTime.now().millisecondsSinceEpoch}',
    };
    final sessions = List<dynamic>.from(await _repo.getSessions());
    sessions.add(entry);
    await _repo.saveSessions(sessions);
    _programSessions.add(entry);
    _sessionsLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> updateProgramSession(
    String sessionId,
    String programId,
    Map<String, dynamic> body,
  ) async {
    _sessionsLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    final sessions = List<dynamic>.from(await _repo.getSessions());
    final idx = sessions.indexWhere(
      (s) => s is Map && s['_id']?.toString() == sessionId,
    );
    if (idx >= 0) {
      sessions[idx] = {...(sessions[idx] as Map), ...body, '_id': sessionId};
      await _repo.saveSessions(sessions);
    }
    final pidx = _programSessions.indexWhere(
      (s) => s is Map && s['_id']?.toString() == sessionId,
    );
    if (pidx >= 0) {
      _programSessions[pidx] = {
        ...(_programSessions[pidx] as Map),
        ...body,
        '_id': sessionId,
      };
    }
    _sessionsLoading = false;
    notifyListeners();
    return true;
  }
}
