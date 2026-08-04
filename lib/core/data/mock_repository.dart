import '../mock/mock_data.dart';
import '../models/query_intent.dart';
import '../models/query_intent_parser.dart';
import '../matching/provider_matcher.dart';
import '../utils/platform_fee.dart';
import '../utils/team_split.dart';
import 'policies.dart';
import 'app_repository.dart';

/// Demo implementation of [AppRepository] — a thin WRAPPER over [MockData].
///
/// Every method resolves on the same microtask (`Future.value(...)`), so the
/// demo looks identical to direct synchronous access while exposing the
/// async-ready surface that #19's Supabase implementation will satisfy. No data
/// logic lives here: same data, same shapes as MockData.
class MockRepository implements AppRepository {
  const MockRepository();

  // ── Programs & sessions ──────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getPrograms() => Future.value(MockData.programs);
  @override
  Future<List<dynamic>> getProgramsOrThrow() => Future.value(MockData.programs);
  @override
  Future<void> savePrograms(List<dynamic> programs) async =>
      MockData.programs = programs;
  @override
  Future<String?> createProgram(Map<String, dynamic> program) async {
    final id = 'prog_${DateTime.now().millisecondsSinceEpoch}';
    final p = Map<String, dynamic>.from(program)..['_id'] = id;
    MockData.programs = [p, ...MockData.programs];
    final now = DateTime.now();
    final sessions = [
      for (var d = 1; d <= 90; d++)
        {
          '_id': 'sess_${id}_$d',
          'programId': id,
          'title': 'Session',
          'startDate': now.add(Duration(days: d)).toIso8601String(),
          'date': now.add(Duration(days: d)).toIso8601String(),
          'startTime': '05:00 PM',
          'endTime': '06:00 PM',
        },
    ];
    MockData.sessions = [...MockData.sessions, ...sessions];
    return id;
  }

  // ── Roster (Booksy model) — in-memory stub for the offline mock demo ────────
  static final List<Map<String, dynamic>> _orgMembers = [];
  @override
  Future<List<Map<String, dynamic>>> getOrgMembers() async =>
      List<Map<String, dynamic>>.from(_orgMembers);
  @override
  Future<List<Map<String, dynamic>>> getOrgMembersForProvider(
    String organizationId,
  ) async =>
      // Offline demo: mirror the RLS filter (verified + active only) so the
      // athlete picker behaves the same as it does against Supabase.
      _orgMembers
          .where((m) =>
              (m['organization_id']?.toString() ?? organizationId) ==
                  organizationId &&
              (m['is_active'] ?? true) == true &&
              (m['background_check_status'] ?? 'verified') == 'verified')
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
  @override
  Future<String?> createOrgMember(Map<String, dynamic> member) async {
    final id = 'mem_${DateTime.now().millisecondsSinceEpoch}';
    _orgMembers.insert(0, {...member, 'id': id, 'background_check_status': 'none'});
    return id;
  }
  @override
  Future<bool> updateOrgMember(String id, Map<String, dynamic> patch) async {
    final i = _orgMembers.indexWhere((m) => m['id'] == id);
    if (i >= 0) _orgMembers[i] = {..._orgMembers[i], ...patch, 'id': id};
    return i >= 0;
  }
  @override
  Future<bool> deleteOrgMember(String id) async {
    _orgMembers.removeWhere((m) => m['id'] == id);
    return true;
  }

  // ── Commission engine (#5) — process-shared demo state (L-013: static) ──────
  static final List<Map<String, dynamic>> _commissionRates = [];

  @override
  Future<List<Map<String, dynamic>>> getCommissionRates(String memberId) async {
    final rows = _commissionRates
        .where((r) => r['organization_member_id'] == memberId)
        .map((r) => Map<String, dynamic>.from(r))
        .toList()
      ..sort((a, b) => (b['effective_from'] ?? '')
          .toString()
          .compareTo((a['effective_from'] ?? '').toString()));
    return rows;
  }

  @override
  Future<bool> addCommissionRate(
    String memberId, {
    required String type,
    required num value,
  }) async {
    _commissionRates.insert(0, {
      'id': 'cr_${DateTime.now().microsecondsSinceEpoch}',
      'organization_member_id': memberId,
      'commission_type': type,
      'commission_value': value,
      'effective_from': DateTime.now().toUtc().toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    // Mirror the legacy default onto the member so the roster tile stays in sync.
    final i = _orgMembers.indexWhere((m) => m['id'] == memberId);
    if (i >= 0) {
      _orgMembers[i] = {
        ..._orgMembers[i],
        'commission_type': type,
        'commission_value': value,
      };
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>?> findAffiliatableAccount(
      String identifier) async {
    // Offline demo: no user directory to search — always "no match" so the UI
    // falls through to Door B (invite by email).
    return null;
  }

  @override
  Future<String?> affiliateExistingAccount(
    String profileId, {
    Map<String, dynamic>? trainerProfile,
  }) async {
    final id = 'mem_${DateTime.now().millisecondsSinceEpoch}';
    _orgMembers.insert(0, {
      'id': id,
      'member_user_id': profileId,
      'trainer_profile': trainerProfile ?? const {},
      'role': 'trainer',
      'affiliation_status': 'pending',
      'background_check_status': 'none',
    });
    return id;
  }

  @override
  Future<String?> createTrainerInvite({String? email, String? phone}) async =>
      'demo_${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<List<dynamic>> getSessions() => Future.value(MockData.sessions);
  @override
  Future<void> saveSessions(List<dynamic> sessions) async =>
      MockData.sessions = sessions;

  // ── Bookings ─────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getBookings() => Future.value(MockData.bookings);
  @override
  Future<List<dynamic>> getBookingsOrThrow() => Future.value(MockData.bookings);
  @override
  Future<void> saveBookings(List<dynamic> bookings) async =>
      MockData.bookings = bookings;
  @override
  Future<String?> addBooking(Map<String, dynamic> booking) async {
    MockData.addBooking(booking);
    return booking['_id']?.toString();
  }

  @override
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    final list = List<dynamic>.from(MockData.bookings);
    final i = list.indexWhere((b) => (b['_id'] ?? b['id']) == bookingId);
    if (i != -1) {
      list[i]['status'] = status;
      MockData.bookings = list;
    }
    return true;
  }

  // ── Coach OS: waitlist (demo — in-memory, mirrors program_waitlist shape) ───
  // static so the const MockRepository() constructor stays const (the demo repo
  // is a stateless wrapper; this shared list is the demo's waitlist store).
  static final List<Map<String, dynamic>> _waitlist = [];

  @override
  Future<String?> joinWaitlist(Map<String, dynamic> entry) async {
    final id = 'wl-${DateTime.now().microsecondsSinceEpoch}';
    _waitlist.add({
      '_id': id,
      'programId': entry['programId'],
      'programTitle': entry['programTitle'] ?? '',
      'sport': entry['sport'] ?? '',
      'athleteId': entry['athleteId'],
      'athleteFirstName': entry['athleteFirstName'] ?? '',
      'athleteAgeBand': entry['athleteAgeBand'] ?? '',
      'note': entry['note'] ?? '',
      'status': 'waiting',
      'createdAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getMyWaitlistEntries() =>
      Future.value(List<Map<String, dynamic>>.from(_waitlist));

  @override
  Future<bool> cancelWaitlistEntry(String id) async {
    final i = _waitlist.indexWhere((e) => e['_id'] == id);
    if (i == -1) return false;
    _waitlist[i]['status'] = 'cancelled';
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getWaitlistForProvider() => Future.value(
    _waitlist.where((e) => e['status'] == 'waiting' || e['status'] == 'offered').toList(),
  );

  @override
  Future<bool> updateWaitlistStatus(String id, String status) async {
    final i = _waitlist.indexWhere((e) => e['_id'] == id);
    if (i == -1) return false;
    _waitlist[i]['status'] = status;
    // Mirrors open_waitlist_seat (20260729_000800): a coach moving an entry to
    // 'offered' is the demo's stand-in for "a seat opened" — create the OFFER
    // ledger row (24h window) if this entry doesn't already have a live one.
    if (status == 'offered') {
      final already = _waitlistOffers.any(
        (o) =>
            o['entryId'] == id &&
            (o['status'] == 'drafted' || o['status'] == 'sent'),
      );
      if (!already) {
        _waitlistOffers.add({
          '_id': 'wloffer-${DateTime.now().microsecondsSinceEpoch}',
          'entryId': id,
          'status': 'drafted',
          'serviceId': _waitlist[i]['programId'],
          'slotDate': null,
          'slotTime': null,
          'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
          'draftMessageId': null,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    }
    return true;
  }

  // ── Provider Model Rebuild #8: WAITLIST OFFERS (demo — in-memory ledger) ────
  // static so const MockRepository() stays const (L-013). Mirrors waitlist_offers.
  static final List<Map<String, dynamic>> _waitlistOffers = [];

  @override
  Future<List<Map<String, dynamic>>> getWaitlistOffers({String? providerId}) async =>
      _waitlistOffers
          .where((o) => o['status'] != 'declined' && o['status'] != 'expired')
          .toList();

  @override
  Future<Map<String, dynamic>> draftWaitlistOffer(String offerId) async {
    final i = _waitlistOffers.indexWhere((o) => o['_id'] == offerId);
    if (i == -1) return {'error': 'Offer not found.'};
    final offer = _waitlistOffers[i];
    if (offer['status'] != 'drafted') {
      return {'skipped': 'offer status is ${offer['status']}, not drafted.'};
    }
    if (offer['draftMessageId'] != null) {
      return {'skipped': 'offer already has a draft.'};
    }
    final entry = _waitlist.firstWhere(
      (e) => e['_id'] == offer['entryId'],
      orElse: () => const {},
    );
    final program = (entry['programTitle']?.toString().trim().isNotEmpty ?? false)
        ? entry['programTitle'].toString()
        : 'the program';
    final name = entry['athleteFirstName']?.toString();
    final draftId = 'msg-${DateTime.now().microsecondsSinceEpoch}';
    offer['draftMessageId'] = draftId;
    final replyText =
        'Good news — a spot just opened in $program'
        '${(name != null && name.isNotEmpty) ? ' for $name' : ''}. '
        "It's yours if you'd like it — this holds for about 24 hours before it "
        'goes to the next family. Just tap to claim your spot.';
    return {
      'result': 'drafted',
      'offer_id': offerId,
      'draft_id': draftId,
      'reply_text': replyText,
      'note': 'Draft saved (coach-only, demo). Review and send from the '
          'existing draft card — never auto-sent.',
    };
  }

  @override
  Future<String?> acceptWaitlistOffer(String offerId, {String? athleteId}) async {
    final i = _waitlistOffers.indexWhere((o) => o['_id'] == offerId);
    if (i == -1) return null;
    final offer = _waitlistOffers[i];
    if (offer['status'] != 'sent') return null; // honest failure, L-015
    final expiresAt = DateTime.tryParse(offer['expiresAt']?.toString() ?? '');
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) return null;
    offer['status'] = 'accepted';
    final ei = _waitlist.indexWhere((e) => e['_id'] == offer['entryId']);
    if (ei != -1) _waitlist[ei]['status'] = 'converted';
    return 'booking-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Future<bool> declineWaitlistOffer(String offerId) async {
    final i = _waitlistOffers.indexWhere((o) => o['_id'] == offerId);
    if (i == -1) return false;
    final offer = _waitlistOffers[i];
    if (offer['status'] != 'drafted' && offer['status'] != 'sent') return false;
    offer['status'] = 'declined';
    final ei = _waitlist.indexWhere((e) => e['_id'] == offer['entryId']);
    if (ei != -1) _waitlist[ei]['status'] = 'waiting';
    return true;
  }

  // ── Coach OS: recurring weekly slots (demo — in-memory) ─────────────────────
  // static so the const MockRepository() constructor stays const (L-013): the
  // demo repo is a stateless wrapper, so slot + skip state lives in shared static
  // lists that mirror the recurring_slots / slot_exceptions shapes.
  static final List<Map<String, dynamic>> _recurringSlots = [];
  static final List<Map<String, dynamic>> _slotExceptions = []; // {slotId,date,reason}

  @override
  Future<List<Map<String, dynamic>>> getMyRecurringSlots() async {
    final list = List<Map<String, dynamic>>.from(_recurringSlots);
    // active first, then by weekday — mirrors the Supabase order.
    list.sort((a, b) {
      final act = ((b['active'] ?? true) ? 1 : 0) - ((a['active'] ?? true) ? 1 : 0);
      if (act != 0) return act;
      return ((a['dayOfWeek'] ?? 0) as int).compareTo((b['dayOfWeek'] ?? 0) as int);
    });
    return list;
  }

  @override
  Future<String?> createRecurringSlot(Map<String, dynamic> slot) async {
    final id = 'slot-${DateTime.now().microsecondsSinceEpoch}';
    _recurringSlots.add({
      '_id': id,
      'providerId': 'mock-provider',
      'dayOfWeek': slot['dayOfWeek'],
      'startTime': slot['startTime'],
      'durationMinutes': slot['durationMinutes'],
      'capacity': slot['capacity'] ?? 1,
      'priceCents': slot['priceCents'] ?? 0,
      'currency': 'USD',
      'active': slot['active'] ?? true,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  @override
  Future<bool> setRecurringSlotActive(String slotId, bool active) async {
    final i = _recurringSlots.indexWhere((s) => s['_id'] == slotId);
    if (i == -1) return false;
    _recurringSlots[i]['active'] = active;
    return true;
  }

  @override
  Future<bool> skipRecurringSlotWeek(
    String slotId,
    String date, {
    String? reason,
  }) async {
    final exists =
        _slotExceptions.any((e) => e['slotId'] == slotId && e['date'] == date);
    if (!exists) {
      _slotExceptions.add({'slotId': slotId, 'date': date, 'reason': reason ?? ''});
    }
    return true;
  }

  @override
  Future<List<String>> getSlotExceptions(String slotId) async =>
      _slotExceptions
          .where((e) => e['slotId'] == slotId)
          .map((e) => e['date'].toString())
          .toList()
        ..sort();

  // ── Provider Model Rebuild #1: Services / Availability / Locations (demo) ────
  // static so const MockRepository() stays const (L-013). A SERVICE carries no
  // times; ONE weekly _availability grid carries them; bookableSlots() multiplies
  // — so the same edit to _availability re-shapes EVERY service's slots.
  static const String _mockProviderId = 'mock-provider';
  static final List<Map<String, dynamic>> _services = [];
  static final List<Map<String, dynamic>> _availability = []; // {_id,dayOfWeek,startTime,endTime,isBlocked}
  static final List<Map<String, dynamic>> _locations = [];
  static final List<String> _availabilityExceptions = []; // yyyy-MM-dd
  static int _mockBufferMinutes = 0;
  static String? _mockVacationUntil;

  @override
  Future<List<Map<String, dynamic>>> getMyServices() async {
    final list = List<Map<String, dynamic>>.from(_services);
    list.sort((a, b) {
      final act = ((b['active'] ?? true) ? 1 : 0) - ((a['active'] ?? true) ? 1 : 0);
      if (act != 0) return act;
      return (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString());
    });
    return list;
  }

  @override
  Future<String?> createService(Map<String, dynamic> service) async {
    final id = 'svc-${DateTime.now().microsecondsSinceEpoch}';
    _services.add({
      '_id': id,
      'providerId': _mockProviderId,
      'serviceType': service['serviceType'] ?? 'private',
      'title': service['title'],
      'sport': service['sport'],
      'durationMinutes': service['durationMinutes'] ?? 60,
      'priceCents': service['priceCents'] ?? 0,
      'capacity': service['capacity'] ?? 1,
      'locationId': service['locationId'],
      'assignable': service['assignable'] ?? false,
      'active': service['active'] ?? true,
      // Item #7 camp facets (only meaningful when serviceType == 'camp').
      'startsOn': service['startsOn'],
      'endsOn': service['endsOn'],
      'dailyStartTime': service['dailyStartTime'],
      'dailyEndTime': service['dailyEndTime'],
      'ageBand': service['ageBand'],
      'earlyBirdPriceCents': service['earlyBirdPriceCents'],
      'earlyBirdCutoff': service['earlyBirdCutoff'],
      'depositCents': service['depositCents'],
      'createdAt': DateTime.now().toIso8601String(),
    });
    // Item #6: org staffing — which trainers may run this service.
    final ids = (service['assignableMemberIds'] as List?)?.cast<String>();
    if (ids != null && ids.isNotEmpty) _serviceStaffing[id] = List<String>.from(ids);
    return id;
  }

  // Item #6: service_assignable_members mirror (serviceId -> [organization_member id]).
  static final Map<String, List<String>> _serviceStaffing = {};

  @override
  Future<bool> setServiceStaffing(
    String serviceId, {
    required bool assignable,
    required List<String> memberIds,
  }) async {
    final i = _services.indexWhere((s) => s['_id'] == serviceId);
    if (i == -1) return false;
    _services[i]['assignable'] = assignable;
    if (assignable) {
      _serviceStaffing[serviceId] = List<String>.from(memberIds);
    } else {
      _serviceStaffing.remove(serviceId);
    }
    return true;
  }

  @override
  Future<List<String>> getServiceStaffing(String serviceId) async =>
      List<String>.from(_serviceStaffing[serviceId] ?? const []);

  @override
  Future<bool> updateService(String serviceId, Map<String, dynamic> patch) async {
    final i = _services.indexWhere((s) => s['_id'] == serviceId);
    if (i == -1) return false;
    for (final k in const [
      'title',
      'sport',
      'serviceType',
      'durationMinutes',
      'priceCents',
      'capacity',
      'locationId',
      'assignable',
      'active',
    ]) {
      if (patch.containsKey(k)) _services[i][k] = patch[k];
    }
    return true;
  }

  @override
  Future<bool> setServiceActive(String serviceId, bool active) async {
    final i = _services.indexWhere((s) => s['_id'] == serviceId);
    if (i == -1) return false;
    _services[i]['active'] = active;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> bookableSlots({
    required String providerId,
    required String serviceId,
    required String fromDate,
    required String toDate,
  }) async {
    final svc = _services.firstWhere(
      (s) => s['_id'] == serviceId,
      orElse: () => const {},
    );
    if (svc.isEmpty || svc['active'] == false) return [];
    final duration = (svc['durationMinutes'] ?? 60) as int;
    final capacity = (svc['capacity'] ?? 1) as int;
    final locationId = svc['locationId'];
    final locName = _locations.firstWhere(
      (l) => l['_id'] == locationId,
      orElse: () => const {},
    )['name'];
    final from = DateTime.parse(fromDate);
    final to = DateTime.parse(toDate);
    final vacation =
        _mockVacationUntil == null ? null : DateTime.parse(_mockVacationUntil!);
    final out = <Map<String, dynamic>>[];
    for (var d = from;
        !d.isAfter(to);
        d = d.add(const Duration(days: 1))) {
      final iso = d.toIso8601String().substring(0, 10);
      // 0=Sun..6=Sat (Dart weekday is 1=Mon..7=Sun)
      final dow = d.weekday % 7;
      if (vacation != null && !d.isAfter(vacation)) continue;
      if (_availabilityExceptions.contains(iso)) continue;
      final blocks = _availability.where(
        (b) => b['dayOfWeek'] == dow && (b['isBlocked'] != true),
      );
      for (final b in blocks) {
        final start = _parseHm(b['startTime']?.toString());
        final end = _parseHm(b['endTime']?.toString());
        if (start == null || end == null) continue;
        final step = duration + _mockBufferMinutes;
        for (var m = start; m + duration <= end; m += step == 0 ? duration : step) {
          out.add({
            'date': iso,
            'startTime': _fmtHms(m),
            'endTime': _fmtHms(m + duration),
            'capacity': capacity,
            'booked': 0,
            'seatsRemaining': capacity,
            'locationId': locationId,
            'locationName': locName,
          });
        }
      }
    }
    out.sort((a, b) {
      final dc = (a['date'] as String).compareTo(b['date'] as String);
      if (dc != 0) return dc;
      return (a['startTime'] as String).compareTo(b['startTime'] as String);
    });
    return out;
  }

  @override
  Future<Map<String, dynamic>?> refineSetupBundle({
    required String sport,
    required List<Map<String, String>> transcript,
    required Map<String, dynamic> template,
  }) async {
    // Offline mock: no AI. Return null so the controller uses the deterministic,
    // template-derived bundle (the confirm path is fully offline + testable).
    return null;
  }

  int? _parseHm(String? hm) {
    if (hm == null) return null;
    final parts = hm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final mi = int.tryParse(parts[1]);
    if (h == null || mi == null) return null;
    return h * 60 + mi;
  }

  String _fmtHms(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  // ── Provider Model Rebuild #2: group seats / recurring-on-service / packs ────
  // static so const MockRepository() stays const (L-013). These lists are the
  // demo's fake backend for the three multi-booking mechanisms; they mirror the
  // 20260729_0002xx SQL (bookings.service_id/slot_date/slot_time,
  // recurring_bookings.service_id, booking_credits) so the swap to Supabase is a
  // binding change, not a rewrite.
  static const String _mockSearcherId = 'mock-searcher';
  // one row per claimed seat: {id, serviceId, slotDate, slotTime, searcherId,
  // athleteId, athleteFirstName, athleteAgeBand, status, paymentStatus}
  static final List<Map<String, dynamic>> _serviceBookings = [];
  static final List<Map<String, dynamic>> _recurringClaims = [];
  // pack ledger: {serviceId, searcherId, remaining}
  static final List<Map<String, dynamic>> _packCredits = [];

  Map<String, dynamic> _serviceOf(String serviceId) => _services.firstWhere(
        (s) => s['_id'] == serviceId,
        orElse: () => const {},
      );

  int _serviceCapacity(String serviceId) {
    final svc = _serviceOf(serviceId);
    if (svc.isEmpty) return 0;
    final cap = (svc['capacity'] ?? 1) as int;
    return cap < 1 ? 1 : cap;
  }

  // Item #6 resource layer (mirrors enforce_booking_venue_conflict, 20260729_000600):
  // a DIFFERENT service already occupying the same (venue, date, time) is a
  // double-book. Same service_id (group seats sharing one slot) is NOT a conflict.
  bool _venueTaken(String serviceId, String? locationId, String slotDate, String slotTime) {
    if (locationId == null) return false; // no venue -> nothing to conflict on
    return _serviceBookings.any((b) =>
        b['locationId'] == locationId &&
        b['slotDate'] == slotDate &&
        (b['slotTime'] ?? '') == slotTime &&
        b['serviceId'] != serviceId &&
        (b['status'] == 'pending' || b['status'] == 'confirmed'));
  }

  // Item #6 staffing rule (mirrors enforce_service_assignment, 20260729_000610):
  // returns null when the (serviceId, assignedMemberId) pair is ALLOWED, else an
  // honest failure reason string. Only ASSIGNABLE (org) services carry the rule.
  String? _assignmentReject(String serviceId, String? assignedMemberId) {
    final svc = _serviceOf(serviceId);
    if (svc['assignable'] != true) return null; // solo service — no staffing rule
    final type = (svc['serviceType'] ?? 'private').toString();
    if (assignedMemberId == null) {
      // "any available trainer" — group/camp ONLY, never a private 1-on-1.
      if (type != 'group' && type != 'camp') {
        return 'any-available not allowed for a private service';
      }
      return null;
    }
    final staffed = _serviceStaffing[serviceId] ?? const [];
    if (!staffed.contains(assignedMemberId)) {
      return 'trainer not staffed on this service';
    }
    return null;
  }

  @override
  Future<String?> claimGroupSeat({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  }) async {
    // Group seats never pin a trainer (any-available). Route through the shared
    // booking path so the venue + any-available + capacity rules all apply.
    return _bookServiceOccurrence(
      serviceId: serviceId,
      slotDate: slotDate,
      slotTime: slotTime,
      assignedMemberId: null,
      athleteId: athleteId,
      athleteFirstName: athleteFirstName,
      athleteAgeBand: athleteAgeBand,
      idPrefix: 'gseat',
    );
  }

  @override
  Future<String?> bookAssignableService({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? assignedMemberId,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  }) async {
    return _bookServiceOccurrence(
      serviceId: serviceId,
      slotDate: slotDate,
      slotTime: slotTime,
      assignedMemberId: assignedMemberId,
      athleteId: athleteId,
      athleteFirstName: athleteFirstName,
      athleteAgeBand: athleteAgeBand,
      idPrefix: 'svcbk',
    );
  }

  // The one mock booking path for a SERVICE occurrence — mirrors the DB triggers'
  // order: staffing/any-available rule, then venue conflict, then capacity, with
  // the venue DERIVED from the service (as enforce_booking_venue_conflict does).
  Future<String?> _bookServiceOccurrence({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    required String? assignedMemberId,
    required String? athleteId,
    required String? athleteFirstName,
    required String? athleteAgeBand,
    required String idPrefix,
  }) async {
    final capacity = _serviceCapacity(serviceId);
    if (capacity == 0) return null; // no such service

    // Staffing / any-available rule (private assignable requires a named trainer).
    if (_assignmentReject(serviceId, assignedMemberId) != null) return null;

    final locationId = _serviceOf(serviceId)['locationId'] as String?;

    bool sameSlot(Map<String, dynamic> b) =>
        b['serviceId'] == serviceId &&
        b['slotDate'] == slotDate &&
        (b['slotTime'] ?? '') == slotTime &&
        (b['status'] == 'pending' || b['status'] == 'confirmed');

    // Idempotency: the same athlete already holds a seat on this slot -> return it.
    final existing = _serviceBookings.firstWhere(
      (b) =>
          sameSlot(b) &&
          b['searcherId'] == _mockSearcherId &&
          b['athleteId'] == athleteId,
      orElse: () => const {},
    );
    if (existing.isNotEmpty) return existing['id']?.toString();

    // Venue double-book: a DIFFERENT service on the same court+time is rejected.
    if (_venueTaken(serviceId, locationId, slotDate, slotTime)) return null;

    // No-oversell: reject the N+1th claim.
    final taken = _serviceBookings.where(sameSlot).length;
    if (taken >= capacity) return null; // slot FULL — honest failure (L-015)

    final id = '$idPrefix-${DateTime.now().microsecondsSinceEpoch}';
    _serviceBookings.add({
      'id': id,
      'serviceId': serviceId,
      'slotDate': slotDate,
      'slotTime': slotTime,
      'locationId': locationId, // derived venue occupancy
      'assignedMemberId': assignedMemberId,
      'searcherId': _mockSearcherId,
      'athleteId': athleteId,
      'athleteFirstName': athleteFirstName,
      'athleteAgeBand': athleteAgeBand,
      'status': 'pending',
      'paymentStatus': 'unpaid',
    });
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> groupSlotRoster({
    required String serviceId,
    required String slotDate,
    required String slotTime,
  }) async {
    return _serviceBookings
        .where((b) =>
            b['serviceId'] == serviceId &&
            b['slotDate'] == slotDate &&
            (b['slotTime'] ?? '') == slotTime &&
            (b['status'] == 'pending' || b['status'] == 'confirmed'))
        .map((b) => <String, dynamic>{
              'bookingId': b['id'],
              'athleteFirstName': b['athleteFirstName'],
              'athleteAgeBand': b['athleteAgeBand'],
              'status': b['status'],
              'paymentStatus': b['paymentStatus'],
            })
        .toList();
  }

  @override
  Future<String?> createRecurringClaim(Map<String, dynamic> claim) async {
    if (claim['serviceId'] == null) return null;
    final id = 'rec-${DateTime.now().microsecondsSinceEpoch}';
    _recurringClaims.add({
      '_id': id,
      'serviceId': claim['serviceId'],
      'searcherId': _mockSearcherId,
      'dayOfWeek': claim['dayOfWeek'],
      'startTime': claim['startTime'],
      'startDate': claim['startDate'],
      'cadence': claim['cadence'] ?? 'weekly',
      'occurrenceCount': claim['occurrenceCount'],
      'endDate': claim['endDate'],
      'billingModel': claim['billingModel'] ?? 'per_session',
      'packageSize': claim['packageSize'],
      'athleteId': claim['athleteId'],
      'athleteFirstName': claim['athleteFirstName'],
      'athleteAgeBand': claim['athleteAgeBand'],
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  @override
  Future<int> creditBalanceForService(String serviceId) async {
    var total = 0;
    for (final c in _packCredits) {
      if (c['serviceId'] == serviceId && c['searcherId'] == _mockSearcherId) {
        total += (c['remaining'] ?? 0) as int;
      }
    }
    return total;
  }

  @override
  Future<String?> redeemPackCredit({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  }) async {
    // No credit to redeem -> honest null (L-015).
    if (await creditBalanceForService(serviceId) <= 0) return null;
    // Book the seat (rides the same no-oversell claim rails).
    final bookingId = await claimGroupSeat(
      serviceId: serviceId,
      slotDate: slotDate,
      slotTime: slotTime,
      athleteId: athleteId,
      athleteFirstName: athleteFirstName,
      athleteAgeBand: athleteAgeBand,
    );
    if (bookingId == null) return null; // slot full / failure
    // Settle: decrement one credit from the first non-empty ledger (mirrors the
    // server-side consume_credit; idempotent per booking because a booking is
    // created once). Mark the seat paid/confirmed.
    final ledger = _packCredits.firstWhere(
      (c) =>
          c['serviceId'] == serviceId &&
          c['searcherId'] == _mockSearcherId &&
          ((c['remaining'] ?? 0) as int) > 0,
      orElse: () => const {},
    );
    if (ledger.isNotEmpty) {
      ledger['remaining'] = ((ledger['remaining'] ?? 0) as int) - 1;
      final seat = _serviceBookings.firstWhere(
        (b) => b['id'] == bookingId,
        orElse: () => const {},
      );
      if (seat.isNotEmpty) {
        seat['paymentStatus'] = 'paid';
        seat['status'] = 'confirmed';
      }
    }
    return bookingId;
  }

  // ── Provider Model Rebuild #7: CAMPS (a service type) + the ops layer ────────
  // static so const MockRepository() stays const (L-013). Mirrors the SQL:
  //   camp_roster (staff-only PII), camp_checkins (per entry per day). Registration
  //   rides the group-seat rails, so capacity auto-close is inherited from
  //   _bookServiceOccurrence — not re-implemented here.
  // {rosterId, serviceId, bookingId, athleteId, athleteFirstName, athleteAgeBand,
  //  emergencyContact, medicalNotes}
  static final List<Map<String, dynamic>> _campRoster = [];
  // {rosterId, day, checkedInAt}
  static final List<Map<String, dynamic>> _campCheckins = [];

  @override
  Future<Map<String, dynamic>?> campPriceDue({
    required String serviceId,
    required String asOf,
  }) async {
    final svc = _serviceOf(serviceId);
    if (svc.isEmpty || (svc['serviceType'] ?? 'private') != 'camp') return null;
    final full = (svc['priceCents'] ?? 0) as int;
    final ebPrice = svc['earlyBirdPriceCents'] as int?;
    final ebCutoff = svc['earlyBirdCutoff'] as String?;
    final deposit = svc['depositCents'] as int?;
    // early-bird applies when set AND asOf <= cutoff (date compare, no toLocal).
    final isEarlyBird = ebPrice != null &&
        ebCutoff != null &&
        !DateTime.parse(asOf).isAfter(DateTime.parse(ebCutoff));
    final effectiveFull = isEarlyBird ? ebPrice : full;
    final dueNow = deposit ?? effectiveFull;
    final balance = (effectiveFull - dueNow) < 0 ? 0 : (effectiveFull - dueNow);
    return <String, dynamic>{
      'fullPriceCents': effectiveFull,
      'dueNowCents': dueNow,
      'balanceCents': balance,
      'isEarlyBird': isEarlyBird,
      'hasDeposit': deposit != null,
    };
  }

  @override
  Future<String?> registerCampAthlete({
    required String serviceId,
    required String athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
    Map<String, dynamic>? emergencyContact,
    String? medicalNotes,
  }) async {
    final svc = _serviceOf(serviceId);
    if (svc.isEmpty || (svc['serviceType'] ?? 'private') != 'camp') return null;
    final startsOn = svc['startsOn'] as String?;
    if (startsOn == null) return null; // a camp needs a start date to register
    // Ride the group-seat rails at the canonical camp-slot identity
    // (service, starts_on, '') — capacity auto-close is INHERITED (L-020).
    final bookingId = await claimGroupSeat(
      serviceId: serviceId,
      slotDate: startsOn,
      slotTime: '',
      athleteId: athleteId,
      athleteFirstName: athleteFirstName,
      athleteAgeBand: athleteAgeBand,
    );
    if (bookingId == null) return null; // camp FULL — honest failure (L-015)
    // Upsert the staff roster row (idempotent on bookingId — no duplicate on re-tap).
    final existing = _campRoster.firstWhere(
      (r) => r['bookingId'] == bookingId,
      orElse: () => const {},
    );
    if (existing.isNotEmpty) {
      existing['emergencyContact'] = emergencyContact;
      existing['medicalNotes'] = medicalNotes;
      return bookingId;
    }
    _campRoster.add({
      'rosterId': 'croster-${DateTime.now().microsecondsSinceEpoch}',
      'serviceId': serviceId,
      'bookingId': bookingId,
      'athleteId': athleteId,
      'athleteFirstName': athleteFirstName,
      'athleteAgeBand': athleteAgeBand,
      'emergencyContact': emergencyContact,
      'medicalNotes': medicalNotes,
    });
    return bookingId;
  }

  @override
  Future<List<Map<String, dynamic>>> campRoster({
    required String serviceId,
    required String day,
    bool asStaff = true,
  }) async {
    // Staff-ONLY (L-005): a non-staff caller sees NOTHING, exactly as the DB RLS
    // returns 0 rows to a parent/other-org (the real backend enforces this; the
    // asStaff switch exercises that gate in the demo/tests).
    if (!asStaff) return const [];
    return _campRoster.where((r) => r['serviceId'] == serviceId).map((r) {
      final checkin = _campCheckins.firstWhere(
        (c) => c['rosterId'] == r['rosterId'] && c['day'] == day,
        orElse: () => const {},
      );
      return <String, dynamic>{
        'rosterId': r['rosterId'],
        'bookingId': r['bookingId'],
        'athleteFirstName': r['athleteFirstName'],
        'athleteAgeBand': r['athleteAgeBand'],
        'emergencyContact': r['emergencyContact'],
        'medicalNotes': r['medicalNotes'],
        'checkedInAt': checkin.isEmpty ? null : checkin['checkedInAt'],
      };
    }).toList();
  }

  @override
  Future<DateTime?> campCheckIn({
    required String rosterId,
    required String day,
  }) async {
    final row = _campRoster.firstWhere(
      (r) => r['rosterId'] == rosterId,
      orElse: () => const {},
    );
    if (row.isEmpty) return null; // no such roster entry
    final now = DateTime.now();
    final existing = _campCheckins.firstWhere(
      (c) => c['rosterId'] == rosterId && c['day'] == day,
      orElse: () => const {},
    );
    if (existing.isNotEmpty) {
      existing['checkedInAt'] = now; // re-tap refreshes
    } else {
      _campCheckins.add({'rosterId': rosterId, 'day': day, 'checkedInAt': now});
    }
    return now;
  }

  @override
  Future<Map<String, dynamic>> campRecapDraft({
    required String serviceId,
    required String day,
    List<String> skills = const [],
    int? effort,
    String? note,
  }) async {
    if (skills.isEmpty && effort == null && (note == null || note.trim().isEmpty)) {
      return {'error': 'Tap at least one skill, an effort level, or a note.'};
    }
    final svc = _serviceOf(serviceId);
    if (svc.isEmpty || (svc['serviceType'] ?? 'private') != 'camp') {
      return {'error': 'Camp not found.'};
    }
    // Grounded ONLY in the taps (mirrors camp-recap's contract) — no invented
    // facts, no per-child claims beyond first name (L-005/L-012).
    final effortWord = switch (effort) {
      1 => 'steady effort',
      2 => 'solid effort',
      3 => 'outstanding effort',
      _ => null,
    };
    final skillPhrase = skills.isEmpty ? null : skills.take(4).join(', ');
    final recap = [
      if (skillPhrase != null) 'Great day at camp — the group worked on $skillPhrase.'
      else 'Great day at camp today.',
      if (effortWord != null) 'The group showed $effortWord throughout.',
      if (note != null && note.trim().isNotEmpty) note.trim(),
    ].join(' ');
    final registrants = _campRoster.where((r) => r['serviceId'] == serviceId).toList();
    return {
      'created': registrants.length,
      'skipped': 0,
      'recap_text': recap,
      'note': 'Drafts only (mock) — the coach reviews and sends each through '
          'the existing parent-update rails. Nothing was sent.',
    };
  }

  @override
  Future<Map<String, dynamic>> campBroadcast({
    required String serviceId,
    required String message,
  }) async {
    if (message.trim().isEmpty) {
      return {'error': 'serviceId and message are required.'};
    }
    final svc = _serviceOf(serviceId);
    if (svc.isEmpty || (svc['serviceType'] ?? 'private') != 'camp') {
      return {'error': 'Camp not found.'};
    }
    final families = _campRoster
        .where((r) => r['serviceId'] == serviceId)
        .map((r) => r['athleteId'])
        .toSet()
        .length;
    return {
      'drafted': families,
      'families': families,
      'skipped': 0,
      'note': 'Drafts only (mock) — each family gets a coach-only draft. '
          'Nothing was sent; the coach approves + sends from the inbox.',
    };
  }

  // ── Provider Model Rebuild #9: TEAM BLOCKS (buyer construct, split-pay) ───────
  // Static demo stores (L-013: const constructor -> no instance fields). Money is
  // structure-only here (L-003): redeem provisions a consented parent/child +
  // bookings; no charge is wired (bookings land unpaid).
  static final List<Map<String, dynamic>> _teamBlocks = [];
  static final List<Map<String, dynamic>> _teamBlockMembers = [];
  static final List<Map<String, dynamic>> _splitPayLinks = [];
  static final List<Map<String, dynamic>> _teamBlockAthletes = []; // provisioned kids

  /// Test-only view of the provisioned (COPPA-consented) athletes.
  static List<Map<String, dynamic>> get teamBlockAthletesForTest =>
      List.unmodifiable(_teamBlockAthletes);

  /// Test-only view of the split-pay links (a family redeems by their link token;
  /// the token is the link secret, never surfaced on the coach status view).
  static List<Map<String, dynamic>> get splitPayLinksForTest =>
      List.unmodifiable(_splitPayLinks);

  /// Test-only view of the team-session bookings generated by redemptions.
  static List<Map<String, dynamic>> get teamBlockBookingsForTest =>
      _serviceBookings.where((b) => b['teamBlockId'] != null).toList();

  @override
  Future<String?> createTeamBlock({
    required String serviceId,
    String? teamName,
    required int sessionCount,
    required int unitPriceCents,
    required String paymentMode,
    String? onePayerProfileId,
  }) async {
    if (sessionCount <= 0 || unitPriceCents < 0) return null; // honest failure
    if (paymentMode != 'one_payer' && paymentMode != 'split_pay') return null;
    final id = 'tblock-${DateTime.now().microsecondsSinceEpoch}';
    _teamBlocks.add({
      'id': id,
      'serviceId': serviceId,
      'teamName': teamName,
      'sessionCount': sessionCount,
      'unitPriceCents': unitPriceCents,
      'totalCents': sessionCount * unitPriceCents,
      'paymentMode': paymentMode,
      'onePayerProfileId': onePayerProfileId,
      'status': 'draft',
      'currency': 'USD',
    });
    return id;
  }

  @override
  Future<String?> addTeamBlockMember({
    required String teamBlockId,
    String? invitedEmail,
    String? invitedPhone,
    String? memberLabel,
  }) async {
    if (!_teamBlocks.any((b) => b['id'] == teamBlockId)) return null;
    final id = 'tbm-${DateTime.now().microsecondsSinceEpoch}-${_teamBlockMembers.length}';
    _teamBlockMembers.add({
      'id': id,
      'teamBlockId': teamBlockId,
      'invitedEmail': invitedEmail,
      'invitedPhone': invitedPhone,
      'memberLabel': memberLabel,
      'status': 'pending',
      'redeemedBy': null,
      'athleteId': null,
      'athleteFirstName': null,
      'athleteAgeBand': null,
    });
    return id;
  }

  @override
  Future<int?> createSplitPayLinks({required String teamBlockId}) async {
    final block = _teamBlocks.firstWhere(
      (b) => b['id'] == teamBlockId,
      orElse: () => const {},
    );
    if (block.isEmpty || block['paymentMode'] != 'split_pay') return null;
    final members = _teamBlockMembers
        .where((m) => m['teamBlockId'] == teamBlockId && m['status'] != 'removed')
        .toList();
    if (members.isEmpty) return 0;
    // Penny-exact split — SAME math as team_split.splitShares / the DB function.
    final shares = splitShares(block['totalCents'] as int, members.length);
    var count = 0;
    for (var i = 0; i < members.length; i++) {
      final memberId = members[i]['id'];
      final share = shares[i];
      final existing = _splitPayLinks.firstWhere(
        (l) => l['memberId'] == memberId,
        orElse: () => const {},
      );
      if (existing.isNotEmpty) {
        existing['shareAmountCents'] = share; // refresh, keep token + status
        existing['platformFeeCents'] = feeCentsFor(share, kFirstBookingFeeBps);
      } else {
        _splitPayLinks.add({
          'id': 'spl-${DateTime.now().microsecondsSinceEpoch}-$i',
          'teamBlockId': teamBlockId,
          'memberId': memberId,
          'invitedEmail': members[i]['invitedEmail'],
          'invitedPhone': members[i]['invitedPhone'],
          'shareAmountCents': share,
          'platformFeeCents': feeCentsFor(share, kFirstBookingFeeBps),
          'currency': 'USD',
          'token': 'tok-${DateTime.now().microsecondsSinceEpoch}-$i',
          'status': 'pending',
          'paidAt': null,
          'payerProfileId': null,
        });
      }
      count++;
    }
    return count;
  }

  @override
  Future<int?> redeemSplitShare({
    required String token,
    required String athleteFirstName,
    String? athleteDob,
    required String consentVersion,
  }) async {
    // COPPA gate (L-005): consent MUST be captured before any athlete/booking.
    if (consentVersion.trim().isEmpty) return null;
    if (athleteFirstName.trim().isEmpty) return null;
    final link = _splitPayLinks.firstWhere(
      (l) => l['token'] == token,
      orElse: () => const {},
    );
    if (link.isEmpty || link['status'] != 'pending') return null; // used/invalid
    final block = _teamBlocks.firstWhere(
      (b) => b['id'] == link['teamBlockId'],
      orElse: () => const {},
    );
    if (block.isEmpty) return null;

    final parentId = _demoParentId; // the caller's (new) parent account
    // Provision the athlete WITH consent captured now (gate satisfied, not bypassed).
    final athleteId = 'ath-${DateTime.now().microsecondsSinceEpoch}';
    final band = _ageBand(athleteDob);
    _teamBlockAthletes.add({
      'id': athleteId,
      'parentId': parentId,
      'firstName': athleteFirstName.trim(),
      'dateOfBirth': athleteDob,
      'parentConsent': true,
      'consentVersion': consentVersion.trim(),
      'consentAt': DateTime.now().toIso8601String(),
    });

    // Mark the share paid (structure — no real charge, L-003) + record the payer.
    link['status'] = 'paid';
    link['paidAt'] = DateTime.now().toIso8601String();
    link['payerProfileId'] = parentId;

    // Attach the roster member to the new parent + child.
    final member = _teamBlockMembers.firstWhere(
      (m) => m['id'] == link['memberId'],
      orElse: () => const {},
    );
    if (member.isNotEmpty) {
      member['status'] = 'onboarded';
      member['redeemedBy'] = parentId;
      member['athleteId'] = athleteId;
      member['athleteFirstName'] = athleteFirstName.trim();
      member['athleteAgeBand'] = band;
    }

    // Generate the block's N session bookings for this child (existing rail; unpaid).
    final n = block['sessionCount'] as int;
    for (var i = 0; i < n; i++) {
      _serviceBookings.add({
        'id': 'tbk-${DateTime.now().microsecondsSinceEpoch}-$i',
        'searcherId': parentId,
        'serviceId': block['serviceId'],
        'teamBlockId': block['id'],
        'athleteId': athleteId,
        'athleteFirstName': athleteFirstName.trim(),
        'athleteAgeBand': band,
        'status': 'confirmed',
        'paymentStatus': 'unpaid',
      });
    }
    if (block['status'] == 'draft') block['status'] = 'active';
    return n;
  }

  @override
  Future<List<Map<String, dynamic>>> teamBlockSplitStatus({
    required String teamBlockId,
  }) async {
    return _teamBlockMembers
        .where((m) => m['teamBlockId'] == teamBlockId && m['status'] != 'removed')
        .map((m) {
      final link = _splitPayLinks.firstWhere(
        (l) => l['memberId'] == m['id'],
        orElse: () => const {},
      );
      return <String, dynamic>{
        'memberId': m['id'],
        'memberLabel': m['memberLabel'],
        'invitedEmail': m['invitedEmail'],
        'invitedPhone': m['invitedPhone'],
        'shareAmountCents': link.isEmpty ? null : link['shareAmountCents'],
        'platformFeeCents': link.isEmpty ? null : link['platformFeeCents'],
        'linkStatus': link.isEmpty ? null : link['status'],
        'paidAt': link.isEmpty ? null : link['paidAt'],
        'memberStatus': m['status'],
        'athleteFirstName': m['athleteFirstName'],
      };
    }).toList();
  }

  static const String _demoParentId = 'demo-parent';
  String? _ageBand(String? dob) {
    if (dob == null) return null;
    final born = DateTime.tryParse(dob);
    if (born == null) return null;
    final age = (DateTime.now().difference(born).inDays / 365.25).floor();
    if (age < 6) return 'under 6';
    if (age < 9) return '6-8';
    if (age < 12) return '9-11';
    if (age < 15) return '12-14';
    if (age < 18) return '15-17';
    return '18+';
  }

  // ── Provider Model Rebuild #6: org scheduling grid + shared inbox ────────────
  String _memberName(String memberId) {
    final m = _orgMembers.firstWhere((x) => x['id'] == memberId, orElse: () => const {});
    return (m['name'] ?? m['displayName'] ?? m['trainer_profile']?['display_name'] ?? 'Trainer')
        .toString();
  }

  @override
  Future<List<Map<String, dynamic>>> orgScheduleGrid({
    required String fromDate,
    required String toDate,
  }) async {
    // Group the org's service bookings by (venue, trainer, slot) — mirrors
    // org_schedule_grid (20260729_000600). One row per occupied cell.
    final agg = <String, Map<String, dynamic>>{};
    for (final b in _serviceBookings) {
      final status = b['status'];
      if (status != 'pending' && status != 'confirmed') continue;
      final date = b['slotDate']?.toString();
      if (date == null || date.compareTo(fromDate) < 0 || date.compareTo(toDate) > 0) {
        continue;
      }
      final locId = b['locationId'];
      if (locId == null) continue; // no venue -> not in the grid
      final svcId = b['serviceId']?.toString() ?? '';
      final time = (b['slotTime'] ?? '').toString();
      final member = b['assignedMemberId'];
      final key = '$locId|$time|$svcId|$date|$member';
      final cell = agg.putIfAbsent(key, () {
        final svc = _serviceOf(svcId);
        final loc = _locations.firstWhere((l) => l['_id'] == locId, orElse: () => const {});
        final trainerName = member == null ? 'Any available' : _memberName(member);
        return <String, dynamic>{
          'date': date,
          'slotTime': time,
          'locationId': locId,
          'locationName': loc['name'],
          'serviceId': svcId,
          'serviceTitle': svc['title'],
          'assignedMemberId': member,
          'trainerName': trainerName,
          'booked': 0,
          'capacity': _serviceCapacity(svcId),
          'hasConflict': false,
        };
      });
      cell['booked'] = (cell['booked'] as int) + 1;
    }
    // Conflict flag: 2+ distinct services on one (venue, date, time). The guard
    // prevents this being persisted; the flag is honest (false) for guarded data.
    for (final cell in agg.values) {
      final peers = agg.values.where((o) =>
          o['locationId'] == cell['locationId'] &&
          o['date'] == cell['date'] &&
          o['slotTime'] == cell['slotTime']);
      final distinctServices = peers.map((o) => o['serviceId']).toSet();
      cell['hasConflict'] = distinctServices.length > 1;
    }
    final rows = agg.values.toList();
    rows.sort((a, b) {
      final dc = (a['date'] as String).compareTo(b['date'] as String);
      if (dc != 0) return dc;
      return (a['slotTime'] as String).compareTo(b['slotTime'] as String);
    });
    return rows;
  }

  // Shared inbox demo store: {conversationId, parentFirstName, serviceId,
  // assignedMemberId, lastMessage, lastMessageAt, draftId, draftBody, ...}
  static final List<Map<String, dynamic>> _orgConversations = [];

  @override
  Future<bool> routeConversation({
    required String conversationId,
    String? serviceId,
    String? memberId,
  }) async {
    // Auto-route (mirrors enforce_conversation_routing): when a service is named
    // and no trainer is chosen, default to the SOLE staffed trainer if there is
    // exactly one.
    var member = memberId;
    if (member == null && serviceId != null) {
      final staffed = _serviceStaffing[serviceId] ?? const [];
      if (staffed.length == 1) member = staffed.first;
    }
    final i = _orgConversations.indexWhere((c) => c['conversationId'] == conversationId);
    final svc = serviceId == null ? const {} : _serviceOf(serviceId);
    final row = <String, dynamic>{
      'conversationId': conversationId,
      'serviceId': serviceId,
      'serviceTitle': svc['title'],
      'assignedMemberId': member,
      'trainerName': member == null ? 'Unassigned' : _memberName(member),
    };
    if (i == -1) {
      _orgConversations.add({
        'parentFirstName': null,
        'lastMessage': null,
        'lastMessageAt': null,
        'hasPendingDraft': false,
        'draftId': null,
        'draftBody': null,
        'draftIntent': null,
        'draftConfidence': null,
        ...row,
      });
    } else {
      _orgConversations[i].addAll(row);
    }
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> orgInbox() async {
    final rows = List<Map<String, dynamic>>.from(_orgConversations);
    rows.sort((a, b) {
      final dp = ((b['hasPendingDraft'] ?? false) ? 1 : 0) -
          ((a['hasPendingDraft'] ?? false) ? 1 : 0);
      if (dp != 0) return dp;
      return (b['lastMessageAt'] ?? '').toString().compareTo((a['lastMessageAt'] ?? '').toString());
    });
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getWeeklyAvailability() async {
    final list = List<Map<String, dynamic>>.from(_availability);
    list.sort((a, b) {
      final dc = ((a['dayOfWeek'] ?? 0) as int).compareTo((b['dayOfWeek'] ?? 0) as int);
      if (dc != 0) return dc;
      return (a['startTime'] ?? '').toString().compareTo((b['startTime'] ?? '').toString());
    });
    return list;
  }

  @override
  Future<bool> setWeeklyAvailability(List<Map<String, dynamic>> blocks) async {
    _availability.clear();
    for (final b in blocks) {
      if (b['dayOfWeek'] == null) continue;
      _availability.add({
        '_id': 'avail-${_availability.length}-${DateTime.now().microsecondsSinceEpoch}',
        'dayOfWeek': b['dayOfWeek'],
        'startTime': _normalizeHms(b['startTime']?.toString()),
        'endTime': _normalizeHms(b['endTime']?.toString()),
        'isBlocked': false,
      });
    }
    return true;
  }

  // Accept "HH:mm" or "HH:mm:ss" and normalize to "HH:mm:ss" (Supabase TIME shape).
  String? _normalizeHms(String? v) {
    if (v == null) return null;
    final parts = v.split(':');
    if (parts.length == 2) return '$v:00';
    return v;
  }

  @override
  Future<Map<String, dynamic>> getAvailabilitySettings() async => {
        'bufferMinutes': _mockBufferMinutes,
        'vacationUntil': _mockVacationUntil,
      };

  @override
  Future<bool> setAvailabilitySettings(
      {int? bufferMinutes, String? vacationUntil}) async {
    if (bufferMinutes != null) _mockBufferMinutes = bufferMinutes;
    _mockVacationUntil = vacationUntil;
    return true;
  }

  @override
  Future<List<String>> getAvailabilityExceptions() async =>
      List<String>.from(_availabilityExceptions)..sort();

  @override
  Future<bool> addAvailabilityException(String date, {String? reason}) async {
    if (!_availabilityExceptions.contains(date)) {
      _availabilityExceptions.add(date);
    }
    return true;
  }

  @override
  Future<bool> removeAvailabilityException(String date) async {
    _availabilityExceptions.remove(date);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getMyLocations() async {
    final list = List<Map<String, dynamic>>.from(_locations);
    list.sort((a, b) =>
        (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return list;
  }

  @override
  Future<String?> createLocation(Map<String, dynamic> location) async {
    final id = 'loc-${DateTime.now().microsecondsSinceEpoch}';
    _locations.add({
      '_id': id,
      'name': location['name'],
      'addressLine1': location['addressLine1'],
      'addressLine2': location['addressLine2'],
      'city': location['city'],
      'state': location['state'],
      'zip': location['zip'],
      'country': location['country'],
      'lat': location['lat'],
      'lng': location['lng'],
      'active': true,
    });
    return id;
  }

  @override
  Future<bool> updateLocation(String locationId, Map<String, dynamic> patch) async {
    final i = _locations.indexWhere((l) => l['_id'] == locationId);
    if (i == -1) return false;
    for (final k in const [
      'name',
      'addressLine1',
      'addressLine2',
      'city',
      'state',
      'zip',
      'country',
      'lat',
      'lng',
      'active',
    ]) {
      if (patch.containsKey(k)) _locations[i][k] = patch[k];
    }
    return true;
  }

  @override
  Future<bool> deleteLocation(String locationId) async {
    _locations.removeWhere((l) => l['_id'] == locationId);
    // Un-pin any service that referenced it (mirror the DB SET NULL).
    for (final s in _services) {
      if (s['locationId'] == locationId) s['locationId'] = null;
    }
    return true;
  }

  // ── Coach OS: earnings (demo — derived from paid mock bookings) ─────────────
  @override
  Future<List<Map<String, dynamic>>> getProviderEarnings() async {
    final out = <Map<String, dynamic>>[];
    for (final b in MockData.bookings) {
      final pay = (b['paymentStatus'] ?? '').toString();
      if (pay != 'paid' && pay != 'partially_refunded') continue;
      final prog = b['programId'];
      final sess = b['sessionId'];
      final ath = b['athleteId'];
      final family =
          (b['searcherId'] ?? (ath is Map ? ath['_id'] : null) ?? '').toString();
      out.add({
        'id': (b['_id'] ?? '').toString(),
        'family': family,
        'date': (sess is Map ? sess['startDate'] ?? sess['date'] : null) ?? b['createdAt'],
        'createdAt': b['createdAt'],
        'athlete': ath is Map ? (ath['firstName'] ?? '') : '',
        'program': prog is Map ? (prog['title'] ?? '') : '',
        'sport': prog is Map ? (prog['sport'] ?? '') : '',
        'status': b['status'] ?? '',
        'paymentStatus': pay,
        'gross': b['finalPrice'] ?? 0,
        'currency': b['currency'] ?? 'USD',
      });
    }
    return out;
  }

  // ── Coach OS money page #1/#4: demo stubs (no real Stripe / bank rail) ───────
  // MockRepository stays const (L-013), so demo invoice/contact state lives in
  // process-shared static fields. No money moves; payouts are empty (honest —
  // the demo has no connected Stripe account).
  static final List<Map<String, dynamic>> _mockContacts = [];
  static final List<Map<String, dynamic>> _mockInvoices = [];

  @override
  Future<List<Map<String, dynamic>>> getProviderPayouts() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getCoachContacts() async =>
      List<Map<String, dynamic>>.from(_mockContacts);

  @override
  Future<String?> createCoachContact(Map<String, dynamic> contact) async {
    final id = 'contact_${DateTime.now().millisecondsSinceEpoch}';
    _mockContacts.insert(0, {'id': id, ...contact});
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getCoachInvoices() async =>
      List<Map<String, dynamic>>.from(_mockInvoices);

  @override
  Future<String?> createCoachInvoiceDraft(Map<String, dynamic> draft) async {
    final id = 'inv_${DateTime.now().millisecondsSinceEpoch}';
    // Mirror the server: sum the line items + derive the near-zero SaaS fee, so
    // the demo shows the same numbers the DB trigger would pin.
    final items = (draft['lineItems'] as List?) ?? const [];
    var amount = 0;
    for (final it in items) {
      if (it is Map) {
        final qty = (it['qty'] as num?)?.toInt() ?? 0;
        final unit = (it['unit_amount_cents'] as num?)?.toInt() ?? 0;
        amount += qty * unit;
      }
    }
    final fee = (amount * 250 / 10000).round();
    final contact = _mockContacts.firstWhere(
      (c) => c['id'] == draft['contactId'],
      orElse: () => const {'displayName': 'Family'},
    );
    _mockInvoices.insert(0, {
      'id': id,
      'contactId': draft['contactId'],
      'contactName': contact['displayName'],
      'description': draft['description'],
      'lineItems': items,
      'amountCents': amount,
      'applicationFeeCents': fee,
      'currency': draft['currency'] ?? 'USD',
      'status': 'draft',
      'dueDate': draft['dueDate'],
    });
    return id;
  }

  // ── Session notes + parent updates (demo: echo back, no AI/network) ─────────
  @override
  Future<String?> createSessionNote(Map<String, dynamic> note) async =>
      'mock-note-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<Map<String, dynamic>> summarizeSessionNote(
    Map<String, dynamic> payload,
  ) async => {
    'result': {
      'type': 'draft',
      'summary_body':
          '${payload['childFirstName'] ?? 'Your athlete'} had a focused ${payload['sport'] ?? ''} session.',
      'skills_worked': const <String>[],
      'progress_signal': 'building consistency',
      'practice_suggestions': const <String>[],
      'encouragement': 'Keep it up!',
    },
    'removed': const <String>[],
  };

  @override
  Future<Map<String, dynamic>> draftRecap(
    Map<String, dynamic> payload,
  ) async {
    // Offline demo: a grounded recap built ONLY from the tapped facts (mirrors
    // the draft-recap function's contract — nothing invented).
    final name = (payload['childFirstName'] as String?)?.trim();
    final skills = (payload['skills'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final effort = payload['effort'] as int?;
    final who = (name == null || name.isEmpty) ? 'Your athlete' : name;
    final effortWord = switch (effort) {
      1 => 'steady effort',
      2 => 'solid effort',
      3 => 'outstanding effort',
      _ => null,
    };
    final skillPhrase =
        skills.isEmpty ? 'the fundamentals' : skills.take(3).join(', ');
    final recap = [
      'Great session with $who today — we worked on $skillPhrase.',
      if (effortWord != null) '$who showed $effortWord throughout.',
    ].join(' ');
    return {
      'result': {'recap_text': recap},
      'note': 'Draft only (mock).',
    };
  }

  // ── Lifecycle automated messaging (P4/P6) — in-memory demo ────────────────
  static final Map<String, String> _lifecyclePrefs = {};
  static final List<Map<String, dynamic>> _lifecycleDrafts = [
    {
      'id': 'lc-draft-1',
      'eventType': 'post_session',
      'childId': null,
      'bookingId': null,
      'body':
          'Hi! Just checking in after today\'s session — it was a good one. Let me know if you have any questions before next time!',
      'scheduledFor': null,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getLifecyclePrefs() async =>
      _lifecyclePrefs.entries
          .map((e) => {'eventType': e.key, 'mode': e.value})
          .toList();

  @override
  Future<bool> setLifecyclePref(String eventType, String mode) async {
    // Mirror the DB rule: 'auto' only valid for logistics types.
    const logistics = {'booking_confirmed', 'reminder_24h'};
    if (mode == 'auto' && !logistics.contains(eventType)) return false;
    _lifecyclePrefs[eventType] = mode;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getLifecycleDrafts() async =>
      List<Map<String, dynamic>>.from(_lifecycleDrafts);

  @override
  Future<Map<String, dynamic>> approveLifecycleMessage(
    String id, {
    String? body,
  }) async {
    _lifecycleDrafts.removeWhere((d) => d['id'] == id);
    return {'ok': true, 'status': 'sent'};
  }

  @override
  Future<Map<String, dynamic>> draftMessage(
    Map<String, dynamic> payload,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600)); // mimic round-trip
    final intent = (payload['intent'] ?? 'reply').toString();
    final reschedule = intent == 'reschedule';
    return {
      'result': {
        'type': 'drafts',
        'drafts': [
          {
            'text': reschedule
                ? 'No problem at all — happy to move the session. What day works best on your end this week? I\'ll get it set up.'
                : 'Thanks for reaching out! Happy to help with that — let me know what works best and we\'ll sort it out.',
          },
          {
            'text': reschedule
                ? 'Thanks for the heads up! I have a couple of openings later this week — just tell me what\'s easiest and I\'ll lock it in.'
                : 'Got it! I\'ll take care of this. Let me know if there\'s anything else you need in the meantime.',
          },
        ],
      },
      'removed': const <String>[],
      'note': 'Drafts only — not saved, not sent.',
    };
  }

  // ── AI assistant chat (demo: local heuristic, no network/model) ─────────────
  @override
  Future<Map<String, dynamic>> askAssistant(
    List<Map<String, String>> messages,
  ) async {
    await Future.delayed(const Duration(milliseconds: 650));
    final last = messages.isNotEmpty ? (messages.last['content'] ?? '') : '';
    final q = last.toLowerCase().trim();
    final first = (MockData.userProfile['firstName'] ?? 'there').toString();

    String reply;
    if (q.isEmpty) {
      reply =
          "I'm here whenever you're ready — ask me about finding a coach, planning a training week, or getting set for a session.";
    } else if (RegExp(r'\b(hi|hey|hello|yo|sup)\b').hasMatch(q)) {
      reply =
          "Hey $first! I can help you find a coach, plan training, or prep for an upcoming session. What are you working on?";
    } else if (q.contains('coach') ||
        q.contains('find') ||
        q.contains('near')) {
      reply =
          "Tell me the sport, your athlete's age, and a budget per session and I'll point you to strong matches. You can also open Search to browse coaches on the map.";
    } else if (q.contains('price') ||
        q.contains('cost') ||
        q.contains('\$') ||
        q.contains('budget') ||
        q.contains('cheap')) {
      reply =
          "Programs are priced by the coach — most single sessions run \$35–\$120, with monthly and package options too. Give me a budget and I'll filter to what fits.";
    } else if (q.contains('book') ||
        q.contains('schedule') ||
        q.contains('sign up') ||
        q.contains('session')) {
      reply =
          "To book: open a listing, pick a session slot and your athlete, then confirm. Your upcoming sessions show on Home and the Schedule tab. Want me to suggest a good training cadence?";
    } else if (RegExp(
      r'basketball|soccer|tennis|swim|box|golf|volleyball|baseball|wrestl|track|martial|dance|hockey',
    ).hasMatch(q)) {
      reply =
          "Great one to train consistently. Aim for 2–3 focused sessions a week — mix skill reps with a game-like rep so it transfers. Want beginner drills or a coach recommendation for that sport?";
    } else if (q.contains('drill') ||
        q.contains('practice') ||
        q.contains('improve') ||
        q.contains('better') ||
        q.contains('train')) {
      reply =
          "Start with a short warm-up, one skill focus (10–15 min of quality reps), then apply it in a small-sided or game-like rep. Consistency beats intensity at this age. Tell me the sport and I'll tailor a set.";
    } else if (q.contains('thank')) {
      reply = "Anytime, $first — go get after it. 💪";
    } else {
      reply =
          "I can help with finding coaches, planning training, prepping for sessions, and how booking works on Sporve. Tell me a bit about your athlete and your goal and I'll get specific.";
    }
    return {'text': reply};
  }

  @override
  Future<QueryIntent> parseChatQuery(String query) async {
    await Future.delayed(const Duration(milliseconds: 180));
    return QueryIntentParser.parse(query);
  }

  @override
  Future<List<ProviderMatch>> searchProviders(
    QueryIntent intent, {
    double? originLat,
    double? originLng,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final services = MockData.programs
        .whereType<Map>()
        .map(_enrichService)
        .toList();
    // No hardcoded origin — the distance gate only fires with a real client
    // location, so a default radius never wrongly excludes distant listings.
    return ProviderMatcher.retrieve(
      services,
      intent,
      originLat: originLat,
      originLng: originLng,
    );
  }

  @override
  Future<Map<String, dynamic>> answerChat({
    required String question,
    required List<ProviderMatch> rows,
    required QueryIntentType intentType,
    String? policyText,
    List<Map<String, String>> history = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 450));

    if (intentType == QueryIntentType.questionAboutBooking) {
      return {
        'text': _policyAnswer(question, policyText ?? Policies.text),
        'provider_ids': const <String>[],
      };
    }
    if (intentType == QueryIntentType.other) {
      return {
        'text':
            "I help with finding coaches, planning training, prepping for sessions, and how booking works on Sporve. What would you like to do?",
        'provider_ids': const <String>[],
      };
    }
    if (rows.isEmpty) {
      return {
        'text':
            "I couldn't find any matches for those criteria. Try widening your search — a larger distance or a higher budget usually surfaces options.",
        'provider_ids': const <String>[],
      };
    }
    final take = intentType == QueryIntentType.compare
        ? (rows.length < 2 ? rows.length : 2)
        : (rows.length < 4 ? rows.length : 4);
    final top = rows.take(take).toList();
    final b = StringBuffer();
    b.writeln(
      intentType == QueryIntentType.compare
          ? "Here's how they compare:"
          : "Here are a few that fit:",
    );
    for (final m in top) {
      final dist = m.distanceKm != null
          ? ', ${m.distanceKm!.round()} km away'
          : '';
      b.writeln(
        '• ${m.name} — \$${m.priceDollars}$dist · ${m.ratingAvg}★ (${m.ratingCount} reviews). ${m.serviceTitle}.',
      );
    }
    return {
      'text': b.toString().trim(),
      'provider_ids': top.map((m) => m.providerId).toList(),
    };
  }

  /// Deterministic policy answer — grounded ONLY in [policy] (never invents).
  String _policyAnswer(String question, String policy) {
    final q = question.toLowerCase();
    String section(String header) {
      final lines = policy.split('\n');
      final idx = lines.indexWhere(
        (l) =>
            l.toLowerCase().startsWith('## ') &&
            l.toLowerCase().contains(header),
      );
      if (idx == -1) return '';
      final buf = <String>[];
      for (var i = idx + 1; i < lines.length; i++) {
        final l = lines[i];
        if (l.startsWith('## ')) break;
        if (l.trim().startsWith('- ')) buf.add(l.trim().substring(2));
      }
      return buf.join(' ');
    }

    for (final entry in const {
      'refund': 'refund',
      'cancel': 'cancellation',
      'reschedul': 'rescheduling',
      'card': 'payments',
      'pay': 'payments',
      'book': 'booking',
    }.entries) {
      if (q.contains(entry.key)) {
        final s = section(entry.value);
        if (s.isNotEmpty) return s;
      }
    }
    return "I'm not sure that's covered in our policies — please reach out to support@sporve.com and they'll help.";
  }

  // ── AI discovery (demo: local heuristic parse + filter, no network/model) ───
  @override
  Future<Map<String, dynamic>> searchParse(
    String query, {
    Map<String, dynamic>? locationHint,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final q = query.toLowerCase();

    // sport: first known sport mentioned.
    const sports = [
      'soccer',
      'basketball',
      'tennis',
      'football',
      'swimming',
      'baseball',
      'volleyball',
      'golf',
      'martial arts',
    ];
    String? sport;
    for (final s in sports) {
      if (q.contains(s)) {
        sport = s;
        break;
      }
    }

    // max_price: "under $80" / "$80" / "80 dollars".
    num? maxPrice;
    final priceMatch = RegExp(r'\$?\s*(\d{2,4})').firstMatch(q);
    if (q.contains('under') || q.contains('\$') || q.contains('budget')) {
      if (priceMatch != null) maxPrice = num.tryParse(priceMatch.group(1)!);
    }

    // athlete_age: "12 year old" / "12yo".
    int? age;
    final ageMatch = RegExp(r'(\d{1,2})\s*(?:yo|year)').firstMatch(q);
    if (ageMatch != null) age = int.tryParse(ageMatch.group(1)!);

    // soft attributes: subjective hints.
    final soft = <String>[];
    if (q.contains('beginner')) soft.add('beginner-friendly');
    if (q.contains('patient')) soft.add('patient');
    if (q.contains('competitive') || q.contains('elite')) {
      soft.add('competitive');
    }

    return {
      'sport': sport,
      'athlete_age': age,
      'metro': null,
      'max_price': maxPrice,
      'radius_miles': null,
      'soft_attributes': soft,
    };
  }

  @override
  Future<Map<String, dynamic>> searchExecute(
    Map<String, dynamic> constraints, {
    Map<String, dynamic>? locationHint,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Discovery now honors the SAME hard gates as the chat (sport, price, age,
    // radius, session type, verified+active) via ProviderMatcher, then dedupes
    // to ONE row per business so a 5-listing academy isn't 5 cards.
    final intent = _intentFromConstraints(constraints);
    final services = MockData.programs
        .whereType<Map>()
        .map(_enrichService)
        .toList();
    final rows = ProviderMatcher.retrieve(
      services,
      intent,
      originLat: 25.7617,
      originLng: -80.1918,
    );

    final seen = <String>{};
    final results = <Map<String, dynamic>>[];
    for (final m in rows) {
      if (!seen.add(m.name)) continue; // dedupe by business
      results.add({
        'program_id': m.raw['_id'],
        'title': m.serviceTitle,
        'specialty': m.sport,
        'price': m.priceDollars,
        'rating': m.ratingAvg,
        'review_count': m.ratingCount,
        'has_availability': true,
        'business': m.name,
        'distance_km': m.distanceKm == null
            ? null
            : double.parse(m.distanceKm!.toStringAsFixed(1)),
        'why': _why(m, intent),
      });
    }

    return {
      'gated': false,
      'results': results,
      'relax': results.isEmpty
          ? {'suggestion': 'Try a higher budget or a larger distance.'}
          : null,
    };
  }

  /// Adds the fields retrieval gates on that the demo seed doesn't carry.
  /// (Intentionally does NOT default intensity/availability — those gates only
  /// fire on real data, so the demo isn't over-filtered.)
  static Map<String, dynamic> _enrichService(Map p) {
    final m = Map<String, dynamic>.from(p);
    m['session_types'] ??= const ['one_on_one', 'group'];
    m['account_status'] ??= 'active';
    return m;
  }

  QueryIntent _intentFromConstraints(Map<String, dynamic> c) {
    final sport = (c['sport'] as String?);
    final maxPrice = c['max_price'];
    final age = c['athlete_age'];
    final radius = c['radius_miles'];
    final session = c['session_type'];
    return QueryIntent(
      intentType: QueryIntentType.findProviders,
      sport: (sport != null && sport.isNotEmpty) ? sport : null,
      priceMaxCents: maxPrice is num ? (maxPrice * 100).round() : null,
      age: age is num ? age.toInt() : null,
      maxDistanceKm: radius is num ? radius * 1.60934 : null,
      sessionType: (session is String && session.isNotEmpty) ? session : null,
      sortPreference: SortPreference.fromWire(c['sort']?.toString()),
    );
  }

  String _why(ProviderMatch m, QueryIntent intent) {
    final bits = <String>[];
    if (intent.sport != null) {
      final s = intent.sport!;
      bits.add('${s[0].toUpperCase()}${s.substring(1)}');
    }
    if (intent.sessionType == 'one_on_one') bits.add('private lessons');
    if (intent.priceMaxCents != null) {
      bits.add('under \$${(intent.priceMaxCents! / 100).round()}');
    }
    if (bits.isEmpty) return 'A strong match for what you described.';
    return 'Matches ${bits.join(', ')}.';
  }

  @override
  Future<Map<String, dynamic>> aiMatch(Map<String, dynamic> client) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final sport = (client['sport'] as String?)?.toLowerCase();
    final budget = client['budget_max_per_session'] as num?; // cents
    final matches = MockData.programs
        .where((p) {
          if (p is! Map) return false;
          if (sport != null &&
              !(p['sportType']?.toString().toLowerCase().contains(sport) ??
                  false)) {
            return false;
          }
          if (budget != null &&
              p['price'] is num &&
              ((p['price'] as num) * 100) > budget) {
            return false;
          }
          return true;
        })
        .map(
          (p) => {
            'provider_id': p['_id'],
            'name': p['providerName'] ?? p['title'] ?? 'Coach',
            'title': p['title'] ?? 'Program',
            'sport': p['sportType'] ?? '',
            'score': 80,
            'why': 'A safety-gated, age-appropriate match for your athlete.',
            'price_per_session': ((p['price'] ?? 0) as num).round() * 100,
            'distance_km': 8.0,
            'rating_avg': p['averageRating'] ?? p['rating'] ?? 0,
            'rating_count': p['totalReviews'] ?? 0,
            'available_this_week': true,
          },
        )
        .toList();
    return {
      'matches': matches,
      'note': matches.isEmpty ? 'No age-appropriate matches in this demo.' : '',
      'eligible_count': matches.length,
    };
  }

  @override
  Future<String?> upsertParentUpdateDraft(Map<String, dynamic> update) async {
    final list = List<dynamic>.from(MockData.parentUpdates);
    final existingId = update['id'] as String?;
    if (existingId != null) {
      final i = list.indexWhere((u) => u is Map && u['id'] == existingId);
      if (i != -1) {
        list[i] = {...list[i] as Map, ...update, 'id': existingId};
        MockData.parentUpdates = list;
        return existingId;
      }
    }
    final id = 'pu_${DateTime.now().millisecondsSinceEpoch}';
    list.insert(0, {
      ...update,
      'id': id,
      'status': 'draft',
      'createdAt': DateTime.now().toIso8601String(),
    });
    MockData.parentUpdates = list;
    return id;
  }

  @override
  Future<Map<String, dynamic>?> approveParentUpdate(String id) async {
    final list = List<dynamic>.from(MockData.parentUpdates);
    final i = list.indexWhere((u) => u is Map && u['id'] == id);
    if (i == -1) return null;
    final row = {
      ...list[i] as Map,
      'status': 'approved',
      'approvedAt': DateTime.now().toIso8601String(),
    };
    list[i] = row;
    MockData.parentUpdates = list;
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<Map<String, dynamic>> sendParentUpdate(String id) async {
    final list = List<dynamic>.from(MockData.parentUpdates);
    final i = list.indexWhere((u) => u is Map && u['id'] == id);
    if (i == -1) return {'error': 'That update no longer exists.'};
    final sentAt = DateTime.now().toIso8601String();
    list[i] = {...list[i] as Map, 'status': 'sent', 'sentAt': sentAt};
    MockData.parentUpdates = list;
    return {
      'ok': true,
      'status': 'sent',
      'delivery_channel': 'inbox',
      'sent_at': sentAt,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getParentUpdatesForChild(
    String childId,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (final u in MockData.parentUpdates) {
      if (u is Map &&
          u['childId']?.toString() == childId &&
          u['status'] == 'sent') {
        out.add(Map<String, dynamic>.from(u));
      }
    }
    out.sort(
      (a, b) => (b['sentAt'] ?? b['createdAt'] ?? '').toString().compareTo(
        (a['sentAt'] ?? a['createdAt'] ?? '').toString(),
      ),
    );
    return out;
  }

  // ── Profiles ─────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getUserProfile() =>
      Future.value(MockData.userProfile);
  @override
  Future<void> saveUserProfile(Map<String, dynamic> profile) async =>
      MockData.userProfile = profile;
  @override
  Future<Map<String, dynamic>> getProviderProfile() =>
      Future.value(MockData.providerProfile);
  @override
  Future<void> saveProviderProfile(Map<String, dynamic> profile) async =>
      MockData.providerProfile = profile;

  // ── Coach policies (AI front-office source of truth) ───────────────────────
  // In-memory demo store (L-013: static so the const MockRepository() stays const;
  // also keeps unit tests off GetStorage/MockData, matching every other mock
  // store — waitlist, slots, etc.).
  static final Map<String, dynamic> _coachPolicies = {};

  @override
  Future<Map<String, dynamic>> getCoachPolicies() async {
    final p = _coachPolicies;
    final faq = p['faq'];
    return {
      'cancellationPolicy': p['cancellationPolicy'],
      'whatToBring': p['whatToBring'],
      'travelRadius': p['travelRadius'],
      'sessionNotes': p['sessionNotes'],
      'faq': faq is List
          ? faq
              .whereType<Map>()
              .map((e) => {
                    'question': (e['question'] ?? '').toString(),
                    'answer': (e['answer'] ?? '').toString(),
                  })
              .where((e) =>
                  e['question']!.trim().isNotEmpty &&
                  e['answer']!.trim().isNotEmpty)
              .toList()
          : const <Map<String, String>>[],
    };
  }

  @override
  Future<bool> saveCoachPolicies(Map<String, dynamic> policies) async {
    String? nn(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final faqIn = policies['faq'];
    final cleanFaq = faqIn is List
        ? faqIn
            .whereType<Map>()
            .map((e) => {
                  'question': (e['question'] ?? '').toString().trim(),
                  'answer': (e['answer'] ?? '').toString().trim(),
                })
            .where((e) =>
                e['question']!.isNotEmpty && e['answer']!.isNotEmpty)
            .toList()
        : const <Map<String, String>>[];

    _coachPolicies
      ..['cancellationPolicy'] = nn(policies['cancellationPolicy'])
      ..['whatToBring'] = nn(policies['whatToBring'])
      ..['travelRadius'] = nn(policies['travelRadius'])
      ..['sessionNotes'] = nn(policies['sessionNotes'])
      ..['faq'] = cleanFaq;
    return true;
  }

  // ── Athletes ─────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getAthletes() => Future.value(MockData.athletes);
  @override
  Future<String?> addAthlete(Map<String, dynamic> athlete) async {
    final id = 'athlete_${DateTime.now().millisecondsSinceEpoch}';
    final first = (athlete['firstName'] ?? '').toString();
    final last = (athlete['lastName'] ?? '').toString();
    MockData.athletes = [
      ...MockData.athletes,
      {
        '_id': id,
        'firstName': first,
        'lastName': last,
        'fullName': '$first $last'.trim(),
        if (athlete['dateOfBirth'] != null)
          'dateOfBirth': athlete['dateOfBirth'],
        if (athlete['gender'] != null) 'gender': athlete['gender'],
        if (athlete['skillLevel'] != null) 'skillLevel': athlete['skillLevel'],
      },
    ];
    return id;
  }

  @override
  Future<void> saveAthletes(List<dynamic> athletes) async =>
      MockData.athletes = athletes;

  // ── Conversations & messages ─────────────────────────────────────────────
  @override
  Future<List<dynamic>> getConversations() =>
      Future.value(MockData.conversations);
  @override
  Future<List<dynamic>> getConversationsOrThrow() =>
      Future.value(MockData.conversations);
  @override
  Future<void> saveConversations(List<dynamic> conversations) async =>
      MockData.conversations = conversations;
  @override
  Future<Map<String, dynamic>?> ensureProviderConversation({
    required String providerOwnerId,
    String? programId,
    String? providerName,
  }) async {
    final conversations = List<dynamic>.from(MockData.conversations);
    for (final conversation in conversations) {
      if (conversation is! Map) continue;
      final participants = conversation['participants'];
      if (participants is List &&
          participants.any(
            (participant) =>
                participant is Map &&
                participant['_id']?.toString() == providerOwnerId,
          )) {
        return Map<String, dynamic>.from(conversation);
      }
    }
    final conversation = <String, dynamic>{
      '_id': 'conv_${DateTime.now().millisecondsSinceEpoch}',
      'programId': programId,
      'participants': [
        {'_id': 'current_user', 'role': 'searcher', 'firstName': 'You'},
        {
          '_id': providerOwnerId,
          'role': 'provider',
          'firstName': providerName ?? 'Coach',
        },
      ],
      'lastMessage': null,
    };
    MockData.conversations = [conversation, ...conversations];
    return conversation;
  }

  @override
  Future<List<dynamic>> getMessages(String conversationId) =>
      Future.value(MockData.getMessages(conversationId));
  @override
  Future<void> saveMessages(
    String conversationId,
    List<dynamic> messages,
  ) async => MockData.saveMessages(conversationId, messages);

  @override
  Future<Map<String, dynamic>?> postMessage(
    String conversationId,
    String body,
  ) async {
    final msg = {
      '_id': 'mock-${DateTime.now().millisecondsSinceEpoch}',
      'conversationId': conversationId,
      'text': body,
      'senderId': MockData.userProfile['_id'] ?? 'me',
      'createdAt': DateTime.now().toIso8601String(),
    };
    final msgs = List<dynamic>.from(MockData.getMessages(conversationId))
      ..add(msg);
    MockData.saveMessages(conversationId, msgs);
    return msg;
  }

  @override
  Future<void Function()> subscribeMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  ) async => () {}; // no realtime in the mock

  // AI Front Office #9 — the coach-feedback corpus. L-013: MockRepository has
  // a `const` constructor, so this MUST be `static final`, never an instance
  // field. Mirrors `draft_feedback` (draftId/coachId/action/originalText/
  // finalText/editedAt) for local demo/test parity.
  static final List<Map<String, dynamic>> _draftFeedback = [];

  /// Test-only read of the recorded feedback — mock parity check for #9
  /// ("edit one draft -> the table holds both the original AI text and the
  /// final edited text").
  static List<Map<String, dynamic>> get draftFeedbackForTest =>
      List.unmodifiable(_draftFeedback);

  @override
  Future<bool> resolveDraft({
    required String draftId,
    required String action,
    String? finalText,
  }) async {
    if (action != 'sent_as_is' && action != 'edited' && action != 'discarded') {
      return false;
    }
    // The mock has no single `messages` table — each conversation's thread is
    // stored under its own key, so find the draft by scanning conversations
    // (mirrors the RPC's `where id = p_draft_id` lookup).
    for (final conv in MockData.conversations) {
      if (conv is! Map) continue;
      final convId = conv['_id']?.toString();
      if (convId == null) continue;
      final msgs = List<dynamic>.from(MockData.getMessages(convId));
      final i = msgs.indexWhere(
        (m) => m is Map && m['_id']?.toString() == draftId,
      );
      if (i == -1) continue;

      final draft = Map<String, dynamic>.from(msgs[i] as Map);
      if ((draft['status'] ?? '') != 'ai_draft') {
        // Already resolved (double-tap / stale UI) — mirror the RPC's
        // "not a pending draft" rejection rather than silently re-logging.
        return false;
      }

      final originalText = (draft['text'] ?? '').toString();
      String? finalBody;
      if (action == 'discarded') {
        draft['status'] = 'discarded';
      } else {
        finalBody = action == 'edited'
            ? (finalText ?? '').trim()
            : originalText;
        if (finalBody.isEmpty) return false;
        draft['status'] = 'sent';
        draft['visibleToParent'] = true;
        draft['text'] = finalBody;
      }
      msgs[i] = draft;
      MockData.saveMessages(convId, msgs);

      // #9 — recorded in the SAME call as the message mutation above, so it
      // can never be skipped, mirroring the atomic `resolve_draft` RPC.
      _draftFeedback.add({
        'draftId': draftId,
        'coachId': MockData.userProfile['_id'] ?? 'me',
        'action': action,
        'originalText': originalText,
        'finalText': finalBody,
        'editedAt': DateTime.now().toIso8601String(),
      });
      return true;
    }
    return false; // draft not found
  }

  // ── Teams ────────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getTeams() => Future.value(MockData.teams);
  @override
  Future<void> saveTeams(List<dynamic> teams) async => MockData.teams = teams;

  // ── Notifications ────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getNotificationPrefs() =>
      Future.value(MockData.notificationPrefs);
  @override
  Future<void> saveNotificationPrefs(Map<String, dynamic> prefs) async =>
      MockData.notificationPrefs = prefs;
  @override
  Future<List<dynamic>> getNotifications() =>
      Future.value(MockData.notifications);
  @override
  Future<void> saveNotifications(List<dynamic> notifications) async =>
      MockData.notifications = notifications;
  @override
  Future<void> savePushToken(String token, {String platform = 'web'}) async {}

  // ── Favorites ────────────────────────────────────────────────────────────
  @override
  Future<List<String>> getFavorites() => Future.value(MockData.favorites);
  @override
  Future<void> saveFavorites(List<String> favorites) async =>
      MockData.favorites = favorites;

  // ── Outcome-first (Prompts 1/2/3/5) — in-memory demo, no network/engine ────
  static final List<Map<String, dynamic>> _goals = [];
  static final List<Map<String, dynamic>> _plans = [];
  static final List<Map<String, dynamic>> _proposals = [];

  @override
  Future<Map<String, dynamic>?> getActiveGoal(
    String athleteId, {
    String? sport,
  }) async {
    for (final g in _goals.reversed) {
      if (g['athleteId'] == athleteId &&
          g['status'] == 'active' &&
          (sport == null || g['sport'] == sport)) {
        return Map<String, dynamic>.from(g);
      }
    }
    // DEMO DEFAULT (mock only): a populated goal so the Plan home renders its FULL
    // experience out of the box (scroll, Up Next, Progress, Suggested trainers).
    // A REAL goal the parent creates in intake is stored in _goals and returned
    // above — it OVERRIDES this, and its AI-formulated `headline` drives the top.
    // This is only the demo placeholder so the screen is never blank.
    return {
      '_id': 'goal_demo',
      'athleteId': athleteId,
      'sport': sport ?? 'Basketball',
      'outcomeText': 'Make the freshman team',
      'headline': 'Make the freshman team',
      'targetDate': '2027-08-01',
      'status': 'active',
      'constraints': {'lat': 41.8781, 'lng': -87.6298, 'max_distance_km': 40},
    };
  }

  @override
  Future<String> formulateGoalHeadline(
    String rawOutcome, {
    String? sport,
  }) async {
    // LOCAL HEURISTIC (mock only): no network. Distils the parent's raw sentence
    // into a short headline, GROUNDED — never injects a sport/team/date/level
    // that isn't in [rawOutcome]. Mirrors the deterministic parseChatQuery mock.
    await Future.delayed(const Duration(milliseconds: 120));
    return _headlineFromOutcome(rawOutcome);
  }

  @override
  Future<String?> createGoal(Map<String, dynamic> goal) async {
    final id = 'goal_${DateTime.now().millisecondsSinceEpoch}';
    _goals.add({...goal, '_id': id, 'status': 'active'});
    return id;
  }

  @override
  Future<Map<String, dynamic>?> getPlanForGoal(String goalId) async {
    for (final p in _plans.reversed) {
      if (p['goalId'] == goalId) return Map<String, dynamic>.from(p);
    }
    // DEMO DEFAULT (mock only): a 3-phase plan so the phase-progress bar renders.
    // A real plan from intake (in _plans) is returned above and overrides this.
    return {
      '_id': 'plan_demo_$goalId',
      'goalId': goalId,
      'phases': const [
        {'name': 'Foundations'},
        {'name': 'Development'},
        {'name': 'Performance'},
      ],
      'currentPhaseIndex': 0,
      'status': 'active',
    };
  }

  @override
  Future<String?> createPlan(Map<String, dynamic> plan) async {
    final id = 'plan_${DateTime.now().millisecondsSinceEpoch}';
    _plans.add({...plan, '_id': id, 'status': 'active'});
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getProposals(
    String planId, {
    String status = 'proposed',
  }) async {
    final existing = _proposals
        .where((p) => p['planId'] == planId && p['status'] == status)
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    if (existing.isNotEmpty || status != 'proposed') return existing;
    // DEMO SEED (mock only): ground up to 3 suggestions from the mock programs.
    await generateProposals(planId);
    return _proposals
        .where((p) => p['planId'] == planId && p['status'] == 'proposed')
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  @override
  Future<bool> updateProposalStatus(String proposalId, String status) async {
    final i = _proposals.indexWhere((p) => p['_id'] == proposalId);
    if (i == -1) return false;
    _proposals[i]['status'] = status;
    return true;
  }

  @override
  Future<bool> setBookingProposal(String bookingId, String proposalId) async =>
      true;

  @override
  Future<Map<String, dynamic>?> getLatestDigest(String planId) async => {
    'body': "Ball-handling improving (Coach D's notes)",
    'sessionsCounted': 8,
  };

  @override
  Future<List<Map<String, dynamic>>> getProgressDigestsForChild(
    String athleteId,
  ) async {
    // Grounded over padded (L-010): the local fake backend seeds no digests, so
    // the timeline renders from parent_updates alone offline. Returns [] rather
    // than fabricating a child's development record.
    final out = <Map<String, dynamic>>[];
    for (final d in MockData.progressDigests) {
      if (d is Map && d['athleteId']?.toString() == athleteId) {
        out.add(Map<String, dynamic>.from(d));
      }
    }
    out.sort(
      (a, b) => (b['createdAt'] ?? '').toString().compareTo(
        (a['createdAt'] ?? '').toString(),
      ),
    );
    return out;
  }

  /// Seeds up to 3 GROUNDED proposals for the Plan home so it renders end-to-end
  /// offline. Unlike the old blind `.take(3)`, this resolves the goal behind the
  /// plan and mirrors the engine: it keeps ONLY safety-verified listings
  /// (background check — L-005) that match the goal's sport and fit its budget,
  /// ranked by rating, deduped by business, then writes an HONEST reason from the
  /// listing's real fields (never a fabricated "verified coach, fits your sport"
  /// claim). Empty supply -> no proposals + an honest note (never pad — L-010).
  @override
  Future<Map<String, dynamic>> generateProposals(String planId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _proposals.removeWhere(
      (p) => p['planId'] == planId && p['status'] == 'proposed',
    );

    // Resolve the goal so the demo proposals are grounded in what the parent
    // actually asked for — sport + budget — not an arbitrary program slice.
    final goal = _goalForPlan(planId);
    final sport = (goal?['sport'] ?? '').toString().trim();
    final wantSport = sport.isNotEmpty && sport.toLowerCase() != 'general';
    final budgetPerSessionCents = goal?['budgetMonthlyCents'] is int
        ? ((goal!['budgetMonthlyCents'] as int) / 4).round()
        : null;

    final ranked = groundProposals(
      MockData.programs,
      sport: wantSport ? sport : null,
      budgetPerSessionCents: budgetPerSessionCents,
    );

    var rank = 0;
    for (final program in ranked) {
      _proposals.add({
        '_id': 'prop_${DateTime.now().microsecondsSinceEpoch}_$rank',
        'planId': planId,
        'proposalType': 'book_service',
        'serviceId': program['_id'],
        'providerId': null,
        'reasonText': _mockReason(
          program,
          withinBudget: budgetPerSessionCents != null,
        ),
        'rank': rank,
        'status': 'proposed',
        'program': program,
        'provider': null,
      });
      rank++;
    }
    return {
      'generated': rank,
      'no_supply': rank == 0,
      'note': rank == 0
          ? (wantSport
              ? 'No verified $sport matches yet in your area.'
              : 'No verified matches yet in your area.')
          : '',
      'eligible_count': rank,
    };
  }

  /// The goal row behind [planId] (via the in-memory plan -> goal link), or null
  /// when the plan is the demo default (no stored goal to ground against).
  Map<String, dynamic>? _goalForPlan(String planId) {
    String? goalId;
    for (final p in _plans.reversed) {
      if (p['_id'] == planId) {
        goalId = p['goalId']?.toString();
        break;
      }
    }
    if (goalId == null) return null;
    for (final g in _goals.reversed) {
      if (g['_id'] == goalId) return g;
    }
    return null;
  }

  /// Pure, testable grounding for demo proposals: from [programs], keep ONLY the
  /// safety-verified listings (background check — L-005) that match [sport]
  /// (when given) and fit [budgetPerSessionCents], ranked by rating and deduped
  /// by business, capped at [limit]. No fabrication — every returned row is a
  /// real listing map. This is the demo mirror of the server's `match_eligible`
  /// + rank; keeping it pure lets the safety gate be unit-tested without storage.
  static List<Map<String, dynamic>> groundProposals(
    List<dynamic> programs, {
    String? sport,
    int? budgetPerSessionCents,
    int limit = 3,
  }) {
    final wantedSport = (sport ?? '').trim().toLowerCase();
    final wantSport = wantedSport.isNotEmpty && wantedSport != 'general';
    final candidates = <Map<String, dynamic>>[];
    for (final prog in programs) {
      if (prog is! Map) continue;
      final program = Map<String, dynamic>.from(prog);
      // SAFETY gate (never relaxed): a verified background check is mandatory.
      if (!_mockVerified(program)) continue;
      if (wantSport) {
        final ps =
            (program['sportType'] ?? program['sport'] ?? '').toString();
        if (!ps.toLowerCase().contains(wantedSport)) continue;
      }
      if (budgetPerSessionCents != null) {
        final priceCents =
            (((program['price'] as num?)?.toDouble() ?? 0) * 100).round();
        if (priceCents > budgetPerSessionCents) continue;
      }
      candidates.add(program);
    }
    candidates.sort((a, b) => ((b['averageRating'] as num?) ?? 0)
        .compareTo((a['averageRating'] as num?) ?? 0));
    final seen = <String>{};
    final ranked = <Map<String, dynamic>>[];
    for (final p in candidates) {
      if (seen.add(_mockBusinessName(p).toLowerCase())) ranked.add(p);
      if (ranked.length >= limit) break;
    }
    return ranked;
  }

  // Mirrors ProviderMatcher._isVerified for the demo: a verified BACKGROUND
  // CHECK is required (identity 'verificationStatus' alone is not enough).
  static bool _mockVerified(Map<String, dynamic> program) {
    final prov = program['providerId'];
    final bg = (program['background_check_status'] ??
            (prov is Map ? prov['background_check_status'] : null) ??
            (prov is Map ? prov['backgroundCheckStatus'] : null))
        ?.toString();
    return bg == 'verified';
  }

  static String _mockBusinessName(Map<String, dynamic> program) {
    final prov = program['providerId'];
    return (program['providerName'] ??
            (prov is Map ? prov['businessName'] : null) ??
            'Coach')
        .toString();
  }

  // Honest, GROUNDED reason from the listing's real fields only. Never asserts a
  // credential/background-check claim (mirrors the engine's claim-stripping), so
  // the demo copy matches the production contract.
  static String _mockReason(
    Map<String, dynamic> program, {
    bool withinBudget = false,
  }) {
    final bits = <String>[];
    final sport = (program['sportType'] ?? program['sport'] ?? '').toString();
    bits.add(sport.isEmpty ? 'Coaching' : '$sport coaching');
    final rating = (program['averageRating'] as num?)?.toDouble();
    final reviews = (program['totalReviews'] as num?)?.toInt() ?? 0;
    if (rating != null && rating > 0 && reviews > 0) {
      bits.add('${rating.toStringAsFixed(1)}★ from $reviews reviews');
    }
    var s = '${bits.join(', ')}.';
    if (withinBudget) s += ' Within your monthly budget.';
    return s;
  }

  @override
  Future<Map<String, dynamic>> planProgress(String planId) async => {
    'completed_sessions': 0,
    'upcoming_bookings': 0,
    'digest': null,
    'adapted': false,
  };

  // ── Goal-headline heuristic (mock + shared fallback shape) ─────────────────
  // Distils a raw outcome sentence into a short, GROUNDED headline. It only
  // ever removes words the parent typed (filler openers, a trailing rationale,
  // and an overflow tail) — it never adds a sport/team/date/level.
  static String _headlineFromOutcome(String raw) {
    final s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return '';
    final wordCount = s.split(' ').length;
    // Already concise: keep the parent's words verbatim (cased + cleaned).
    if (s.length <= 40 && wordCount <= 5) {
      return _titleCase(_stripTrailingPunct(s));
    }
    var t = s;
    // Drop a trailing rationale clause ("… because/so/since/in order to …").
    t = t
        .replaceFirst(
          RegExp(
            r'\s+\b(because|so that|so|since|in order to)\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    // Strip leading filler openers, repeatedly.
    const fillers = [
      'i would like to',
      "i'd like to",
      'my goal is to',
      'i want to',
      'we would like to',
      "we'd like to",
      'we want to',
      'we want',
      'help me',
      'trying to',
      'hoping to',
      'i want',
      "i'd like",
      'my goal is',
    ];
    var changed = true;
    while (changed) {
      changed = false;
      final low = t.toLowerCase();
      for (final f in fillers) {
        if (low.startsWith('$f ')) {
          t = t.substring(f.length).trimLeft();
          changed = true;
          break;
        }
      }
    }
    final capped = _stripTrailingStopwords(_truncateWords(t.isEmpty ? s : t));
    final headline = _stripTrailingPunct(capped);
    if (headline.trim().isEmpty) {
      // Nothing usable survived — return the truncated original.
      return _titleCase(
        _stripTrailingPunct(_stripTrailingStopwords(_truncateWords(s))),
      );
    }
    return _titleCase(headline);
  }

  static String _truncateWords(
    String input, {
    int maxWords = 5,
    int maxChars = 40,
  }) {
    final words = input.split(' ').where((w) => w.isNotEmpty).toList();
    final kept = <String>[];
    var len = 0;
    for (final w in words) {
      if (kept.length >= maxWords) break;
      final add = kept.isEmpty ? w.length : len + 1 + w.length;
      if (kept.isNotEmpty && add > maxChars) break;
      kept.add(w);
      len = add;
    }
    return kept.join(' ');
  }

  // Connectives/stopwords that must never dangle at the end of a headline once
  // the ~5-word/~40-char cap has clipped mid-phrase (e.g. "…Make Fun And").
  static const List<String> _trailingStopwords = [
    'and', 'or', 'to', 'the', 'a', 'an', 'for',
    'with', 'of', 'in', 'on', 'at', 'by', '&',
  ];

  // Trim any trailing connective/stopword left dangling after the cap, repeated
  // until none remain. Never trims down to an empty string (keeps ≥1 word).
  static String _stripTrailingStopwords(String s) {
    final words = s.split(' ').where((w) => w.isNotEmpty).toList();
    while (words.length > 1) {
      final last =
          words.last.replaceAll(RegExp(r'[.,;:!?]+$'), '').toLowerCase();
      if (!_trailingStopwords.contains(last)) break;
      words.removeLast();
    }
    return words.join(' ');
  }

  static String _stripTrailingPunct(String s) =>
      s.replaceAll(RegExp(r'[\s.,;:!?]+$'), '');

  static String _titleCase(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map(
        (w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}
