import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/query_intent.dart';
import '../matching/provider_matcher.dart';
import 'app_repository.dart';

/// Real backend implementation of [AppRepository] (#19).
///
/// Reads/writes Supabase (`init.sql` schema) and maps the snake_case DB columns
/// into the EXACT camelCase + `_id` map shapes the UI already consumes (the same
/// shapes [MockData] produces) — so no screen or model changes are needed.
///
/// Conventions honoured:
///  • session dates stay UTC-midnight (`YYYY-MM-DDT00:00:00.000Z`) — never
///    `.toLocal()` (see core/utils/session_time.dart).
///  • writes stamp identity from the auth session so RLS passes
///    (athletes.parent_id / bookings.searcher_id = current user id).
///  • every method is wrapped: on failure it returns empty/clean data so the UI
///    renders its existing empty states instead of crashing.
///
/// A few list-replace writes inherited from the mock surface (chat persistence,
/// favourites, notification prefs) have no dedicated table; those are kept local
/// (GetStorage) or safe no-ops and are noted inline. Auth state is NOT here — it
/// is owned by AuthProvider/AuthService (the Supabase session); see #18.
class SupabaseRepository implements AppRepository {
  SupabaseRepository();

  SupabaseClient get _db => Supabase.instance.client;
  final GetStorage _local = GetStorage();

  String? get _uid => _db.auth.currentUser?.id;

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  bool _isUuid(Object? v) => v is String && _uuidRe.hasMatch(v);

  /// A DB `date`/`timestamp` → the app's UTC-midnight ISO string.
  String? _utcMidnight(dynamic d) {
    if (d == null) return null;
    final s = d.toString();
    if (s.isEmpty) return null;
    // start_date comes back as 'YYYY-MM-DD'; keep the calendar day, pin to UTC.
    final dayOnly = s.length >= 10 ? s.substring(0, 10) : s;
    return '${dayOnly}T00:00:00.000Z';
  }

  double _toD(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
  List<dynamic> _toList(dynamic v) => v is List ? v : const [];

  String? _extractId(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map) return (v['_id'] ?? v['id'])?.toString();
    return null;
  }

  // ── Mappers: DB row (snake_case) → UI map (camelCase + _id) ───────────────

  Map<String, dynamic> _mapProgram(Map row) {
    final prov = row['providers'];
    return {
      '_id': row['id'],
      // The org/provider uuid (FK column) — the athlete-side trainer picker
      // fetches this org's roster with it. Distinct from the embedded
      // providerId map below, which carries display/gate fields but not the id.
      'providerRowId': row['provider_id'],
      'coverImage': row['cover_image'],
      'title': row['title'],
      'description': row['description'],
      'sportType': row['sport_type'],
      'programType': row['program_type'] ?? 'Training',
      'skillLevel': row['skill_level'],
      'ageGroup': row['age_group'],
      'language': row['language'],
      'price': _toD(row['price']),
      'currency': row['currency'],
      'pricingModel': row['pricing_model'],
      'maxCapacity': row['max_capacity'],
      'enrolledCount': row['enrolled_count'],
      'gallery': _toList(row['gallery']),
      'whatsIncluded': _toList(row['whats_included']),
      'location': {
        'type': 'Point',
        'coordinates': [row['longitude'], row['latitude']],
      },
      'address': {
        'line1': row['address_line1'],
        'city': row['city'],
        'state': row['state'],
        'zip': row['zip'],
        'country': row['country'],
      },
      'cancellationPolicy': row['cancellation_policy'],
      'minimumAge': row['minimum_age'],
      'maximumAge': row['maximum_age'],
      'isFeatured': row['is_featured'] ?? false,
      'status': row['status'],
      'averageRating': _toD(row['average_rating']),
      'totalReviews': row['total_reviews'] ?? 0,
      // Gate inputs — grounded from real columns, never fabricated (G4/G5/G7):
      'intensity_tier': row['intensity_tier'],
      'session_types': _toList(row['session_types']),
      'account_status': prov is Map ? prov['account_status'] : null,
      'providerId': prov is Map
          ? {
              'ownerId': prov['owner_id'],
              'businessName': prov['business_name'],
              'verificationStatus': prov['verification_status'],
              // G5 safety gate reads this (mirrors the server match_eligible:
              // background_check_status = 'verified'). Without it the client
              // matcher fails closed and the concierge returns zero matches.
              'backgroundCheckStatus': prov['background_check_status'],
              // Nullable; surfaced for the gold badge tap-through (no date if null).
              'backgroundCheckCompletedAt':
                  prov['background_check_completed_at'],
            }
          : null,
    };
  }

  Map<String, dynamic> _mapSession(Map row) {
    final iso = _utcMidnight(row['start_date']);
    return {
      '_id': row['id'],
      'programId': row['program_id'],
      'title': row['title'],
      'startDate': iso,
      'endDate': _utcMidnight(row['end_date']),
      'date': iso,
      'startTime': row['start_time'],
      'endTime': row['end_time'],
      'timezone': row['timezone'],
      'address': row['address'],
      // Which rostered trainer this slot belongs to (null = shared / any
      // available). Carried through so the athlete-side picker can attribute.
      'assignedMemberId': row['assigned_member_id'],
    };
  }

  Map<String, dynamic> _mapBooking(Map row) {
    final sess = row['sessions'];
    final prog = sess is Map ? sess['programs'] : null;
    final ath = row['athletes'];
    return {
      '_id': row['id'],
      'searcherId': row['searcher_id'],
      'athleteId': ath is Map
          ? {
              '_id': row['athlete_id'],
              'firstName': ath['first_name'] ?? row['athlete_first_name'] ?? '',
              'fullName': '${ath['first_name'] ?? ''} ${ath['last_name'] ?? ''}'
                  .trim(),
              'profileImage': ath['profile_image'],
            }
          : {
              '_id': row['athlete_id'],
              'firstName': row['athlete_first_name'] ?? '',
              'fullName': row['athlete_first_name'] ?? '',
            },
      'programId': prog is Map
          ? {
              '_id': prog['id'],
              'title': prog['title'],
              'sport': prog['sport_type'],
            }
          : row['program_id'],
      'sessionId': sess is Map
          ? {
              '_id': sess['id'],
              'title': sess['title'],
              'date': _utcMidnight(sess['start_date']),
              'startDate': _utcMidnight(sess['start_date']),
              'startTime': sess['start_time'],
              'programId': sess['program_id'],
            }
          : null,
      'selectedTier': row['selected_tier'],
      'originalPrice': _toD(row['original_price']),
      'finalPrice': _toD(row['final_price']),
      'currency': row['currency'],
      'status': row['status'],
      'paymentStatus': row['payment_status'],
      'stripeCheckoutSessionId': row['stripe_checkout_session_id'],
      'createdAt': row['created_at'],
    };
  }

  Map<String, dynamic> _mapAthlete(Map row) => {
    '_id': row['id'],
    'firstName': row['first_name'],
    'lastName': row['last_name'],
    'fullName': '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
    'dateOfBirth': _utcMidnight(row['date_of_birth']),
    'gender': row['gender'],
    'preferredSports': _toList(row['preferred_sports']),
    'medicalConditions': row['medical_conditions'],
    'emergencyContact': row['emergency_contact'],
    'profileImage': row['profile_image'],
  };

  Map<String, dynamic> _mapUserProfile(Map row) => {
    '_id': row['id'],
    'firstName': row['first_name'],
    'lastName': row['last_name'],
    'email': row['email'],
    'role': row['role'],
    'phoneNumber': row['phone_number'],
    'preferredSports': _toList(row['preferred_sports']),
    'profileImage': row['profile_image'],
  };

  Map<String, dynamic> _mapProviderProfile(Map row) => {
    '_id': row['id'],
    'userId': row['owner_id'],
    'businessName': row['business_name'],
    'bio': row['bio'],
    'sports': _toList(row['sports']),
    'location': row['location'],
    'status': row['status'],
    'onboardingCompleted': row['onboarding_completed'] ?? false,
    'verificationStatus': row['verification_status'],
    'backgroundCheckCompletedAt': row['background_check_completed_at'],
    'stripeAccountId': row['stripe_account_id'],
    'stripeChargesEnabled': row['stripe_charges_enabled'] ?? false,
  };

  // ── Programs & sessions ───────────────────────────────────────────────────
  Future<List<dynamic>> _fetchPrograms() async {
    final rows = await _db
        .from('programs')
        .select(
          '*, providers(owner_id, business_name, verification_status, background_check_status, background_check_completed_at, account_status)',
        );
    return (rows as List).map((r) => _mapProgram(r as Map)).toList();
  }

  @override
  Future<List<dynamic>> getPrograms() async {
    try {
      return await _fetchPrograms();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<List<dynamic>> getProgramsOrThrow() => _fetchPrograms();

  @override
  Future<List<dynamic>> getSessions() async {
    try {
      final rows = await _db.from('sessions').select();
      return (rows as List).map((r) => _mapSession(r as Map)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  /// Best-effort upsert of a provider's programs (read-modify-write of the whole
  /// list, mock-style). New rows get the caller's provider_id so RLS passes.
  @override
  Future<void> savePrograms(List<dynamic> programs) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return;
      for (final p in programs) {
        if (p is! Map) continue;
        final row = _programToRow(p, providerId);
        await _db.from('programs').upsert(row);
      }
    } catch (e) {
      debugPrint('SupabaseRepository write failed: $e');
    }
  }

  @override
  Future<String?> createProgram(Map<String, dynamic> program) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return null;
      final row = _programToRow(program, providerId)..remove('id');
      // Publish so it's discoverable; the coach can archive later.
      row['status'] = program['status'] ?? 'published';
      final inserted = await _db
          .from('programs')
          .insert(row)
          .select('id')
          .single();
      final id = inserted['id']?.toString();
      if (id != null) await _seedDefaultSessions(id);
      return id;
    } catch (e) {
      debugPrint('createProgram failed: $e');
      return null;
    }
  }

  // ── Roster: affiliated trainers (Booksy model) ──────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getOrgMembers() async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return [];
      final rows = await _db
          .from('organization_members')
          .select()
          .eq('organization_id', providerId)
          .order('created_at');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('getOrgMembers failed: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrgMembersForProvider(
    String organizationId,
  ) async {
    try {
      // No _currentProviderId() gate: this is the customer-facing read. RLS
      // (organization_members_select_public) returns only verified + active
      // members of an approved org with a published service — an org can never
      // surface an unverified trainer here (L-005).
      // Explicit verified+active filter: fail-closed for EVERY caller. RLS
      // already hides unverified members from a plain searcher, but an org
      // owner/admin browsing their own org would otherwise see all rows via
      // organization_members_select_admin — the picker must never surface an
      // unverified trainer to anyone (L-005).
      final rows = await _db
          .from('organization_members')
          .select()
          .eq('organization_id', organizationId)
          .eq('background_check_status', 'verified')
          .eq('is_active', true)
          .order('created_at');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('getOrgMembersForProvider failed: $e');
      return [];
    }
  }

  @override
  Future<String?> createOrgMember(Map<String, dynamic> member) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return null;
      // An org IS a provider with a roster — flip the type on the first trainer.
      await _db
          .from('providers')
          .update({'provider_type': 'organization'}).eq('id', providerId);
      final row = Map<String, dynamic>.from(member)
        ..['organization_id'] = providerId
        ..remove('id')
        ..remove('background_check_status'); // server-controlled
      final inserted = await _db
          .from('organization_members')
          .insert(row)
          .select('id')
          .single();
      return inserted['id']?.toString();
    } catch (e) {
      debugPrint('createOrgMember failed: $e');
      return null;
    }
  }

  @override
  Future<bool> updateOrgMember(String id, Map<String, dynamic> patch) async {
    try {
      final clean = Map<String, dynamic>.from(patch)
        ..remove('id')
        ..remove('organization_id')
        ..remove('background_check_status'); // server-controlled
      await _db.from('organization_members').update(clean).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateOrgMember failed: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteOrgMember(String id) async {
    try {
      await _db.from('organization_members').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteOrgMember failed: $e');
      return false;
    }
  }

  /// A new listing needs bookable sessions or the booking flow shows "no
  /// upcoming sessions". Seed a DAILY session for the next 90 days so a program
  /// effectively never runs out of bookable slots (the calendar stays full).
  Future<void> _seedDefaultSessions(String programId) async {
    try {
      final now = DateTime.now();
      final rows = [
        for (var d = 1; d <= 90; d++)
          {
            'program_id': programId,
            'title': 'Session',
            'start_date': now
                .add(Duration(days: d))
                .toIso8601String()
                .substring(0, 10),
            'start_time': '05:00 PM',
            'end_time': '06:00 PM',
            'timezone': 'EST',
          },
      ];
      await _db.from('sessions').insert(rows);
    } catch (e) {
      debugPrint('_seedDefaultSessions failed: $e');
    }
  }

  @override
  Future<void> saveSessions(List<dynamic> sessions) async {
    try {
      for (final s in sessions) {
        if (s is! Map) continue;
        final row = _sessionToRow(s);
        if (row['program_id'] == null) continue; // can't satisfy the FK
        await _db.from('sessions').upsert(row);
      }
    } catch (e) {
      debugPrint('SupabaseRepository write failed: $e');
    }
  }

  // ── Bookings ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> _fetchBookings() async {
    final rows = await _db
        .from('bookings')
        .select(
          '*, sessions(*, programs(*)), athletes(first_name,last_name,profile_image)',
        );
    return (rows as List).map((r) => _mapBooking(r as Map)).toList();
  }

  @override
  Future<List<dynamic>> getBookings() async {
    try {
      return await _fetchBookings();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<List<dynamic>> getBookingsOrThrow() => _fetchBookings();

  @override
  Future<void> saveBookings(List<dynamic> bookings) async {
    // No wholesale replace against a shared table; individual creation goes
    // through addBooking; status changes go through updateBookingStatus.
  }

  @override
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      if (!_isUuid(bookingId)) return false;
      // Provider RLS + enforce_booking_provider_update pin this to `status`.
      await _db.from('bookings').update({'status': status}).eq('id', bookingId);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('updateBookingStatus failed: ${e.message}');
      return false;
    }
  }

  @override
  Future<String?> addBooking(Map<String, dynamic> booking) async {
    // RLS WITH CHECK requires searcher_id = auth.uid(); no session => no insert.
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('addBooking: no authenticated user — cannot insert booking');
      return null;
    }

    final programId = _extractId(booking['programId']);
    var sessionId = _extractId(booking['sessionId']);
    // The booking flow invents a synthetic session id; resolve a REAL session
    // for the program so the session_id FK is satisfied. Only consider FUTURE
    // (today-or-later) sessions so we never book one that already happened, and
    // pick the soonest. start_date is a calendar date; compare as 'YYYY-MM-DD'
    // (UTC-midnight convention — no .toLocal()).
    if (!_isUuid(sessionId) && programId != null) {
      try {
        final now = DateTime.now();
        final todayStr =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        final rows = await _db
            .from('sessions')
            .select('id, start_date')
            .eq('program_id', programId)
            .gte('start_date', todayStr)
            .order('start_date')
            .limit(1);
        if (rows.isNotEmpty) {
          sessionId = (rows.first as Map)['id']?.toString();
        }
      } catch (e) {
        debugPrint('addBooking: session lookup failed: $e');
      }
    }
    if (!_isUuid(sessionId)) {
      debugPrint(
        'addBooking: no real session to book for program=$programId '
        '(is the database seeded?) — skipping insert',
      );
      return null;
    }

    final athleteId = _extractId(booking['athleteId']);
    final planProposalId = _extractId(booking['planProposalId']);
    // Booksy attribution: the trainer the athlete chose (null = any available).
    // Pure attribution — it never affects original_price / final_price / the
    // Stripe charge (L-003). The FK guarantees it's a real roster member.
    final assignedMemberId = _extractId(booking['assignedMemberId']);
    // Every key below is a real `bookings` column. searcher_id MUST equal
    // auth.uid() (RLS). status MUST satisfy the CHECK
    // (pending|confirmed|declined|completed) — payment lives in the separate
    // payment_status column, which we let DEFAULT to 'unpaid'.
    final athleteName = booking['athleteName']?.toString();
    final payload = <String, dynamic>{
      'searcher_id': uid,
      'session_id': sessionId,
      if (_isUuid(programId)) 'program_id': programId,
      if (_isUuid(athleteId)) 'athlete_id': athleteId,
      if (_isUuid(assignedMemberId)) 'assigned_member_id': assignedMemberId,
      if (_isUuid(planProposalId)) 'plan_proposal_id': planProposalId,
      if (athleteName != null && athleteName.isNotEmpty)
        'athlete_first_name': athleteName.split(' ').first,
      'selected_tier': booking['selectedTier'],
      'original_price': booking['originalPrice'] ?? 0,
      'final_price': booking['finalPrice'] ?? 0,
      'currency': booking['currency'] ?? 'USD',
      'status': 'pending',
    };

    try {
      final inserted = await _db
          .from('bookings')
          .insert(payload)
          .select('id')
          .single();
      return (inserted as Map)['id']?.toString();
    } on PostgrestException catch (e) {
      // Surface the REAL database reason rather than masking it as a generic
      // "could not create booking" — the caller shows e.message to the user.
      debugPrint(
        'addBooking PostgrestException: code=${e.code} '
        'message=${e.message} details=${e.details} hint=${e.hint}',
      );
      rethrow;
    }
  }

  // ── Session notes + parent updates (AI deliverable) ─────────────────────────
  @override
  Future<String?> createSessionNote(Map<String, dynamic> note) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) {
        debugPrint('createSessionNote: caller is not a provider');
        return null;
      }
      // Prompt 5: structured, provider-authored session notes. focus_areas
      // (chips), effort (1-5), progress_note feed the grounded progress digest;
      // parents never read raw notes.
      final focus = (note['focusAreas'] as List?)?.cast<String>();
      final effort = note['effort'];
      final progressNote = note['progressNote']?.toString();
      final payload = <String, dynamic>{
        'provider_id': providerId,
        'raw_notes': note['rawNotes'] ?? '',
        if (_isUuid(note['bookingId'])) 'booking_id': note['bookingId'],
        if (_isUuid(note['childId'])) 'child_id': note['childId'],
        if (focus != null && focus.isNotEmpty) 'focus_areas': focus,
        if (effort is int && effort >= 1 && effort <= 5) 'effort': effort,
        if (progressNote != null && progressNote.isNotEmpty)
          'progress_note': progressNote,
      };
      final inserted = await _db
          .from('session_notes')
          .insert(payload)
          .select('id')
          .single();
      return (inserted as Map)['id']?.toString();
    } on PostgrestException catch (e) {
      debugPrint('createSessionNote failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> summarizeSessionNote(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _db.functions.invoke(
        'session-note-summarize',
        body: payload,
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('summarizeSessionNote FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not draft the update (status ${e.status}).'};
    } catch (e) {
      debugPrint('summarizeSessionNote failed: $e');
      return {'error': 'Could not draft the update. Please try again.'};
    }
  }

  // ── Lifecycle automated messaging (P4/P6) ─────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getLifecyclePrefs() async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return [];
      final rows = await _db
          .from('lifecycle_message_prefs')
          .select('event_type, mode')
          .eq('provider_id', providerId);
      return (rows as List)
          .map((r) => {'eventType': r['event_type'], 'mode': r['mode']})
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('getLifecyclePrefs failed: ${e.message}');
      return [];
    }
  }

  @override
  Future<bool> setLifecyclePref(String eventType, String mode) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return false;
      // Upsert on (provider_id, event_type). The DB CHECK rejects 'auto' for
      // non-logistics types (surfaces as a PostgrestException -> false).
      await _db.from('lifecycle_message_prefs').upsert({
        'provider_id': providerId,
        'event_type': eventType,
        'mode': mode,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'provider_id,event_type');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('setLifecyclePref rejected/failed: ${e.message}');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getLifecycleDrafts() async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return [];
      final rows = await _db
          .from('outbound_messages')
          .select(
            'id, event_type, child_id, booking_id, content, scheduled_for, created_at',
          )
          .eq('provider_id', providerId)
          .eq('status', 'drafted')
          .order('created_at', ascending: false);
      return (rows as List).map((r) {
        final content = r['content'];
        return {
          'id': r['id'],
          'eventType': r['event_type'],
          'childId': r['child_id'],
          'bookingId': r['booking_id'],
          'body': (content is Map ? content['body'] : null)?.toString() ?? '',
          'scheduledFor': r['scheduled_for'],
        };
      }).toList();
    } on PostgrestException catch (e) {
      debugPrint('getLifecycleDrafts failed: ${e.message}');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> approveLifecycleMessage(
    String id, {
    String? body,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'lifecycle-approve',
        body: {'id': id, 'body': ?body},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('approveLifecycleMessage FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not send the message (status ${e.status}).'};
    } catch (e) {
      debugPrint('approveLifecycleMessage failed: $e');
      return {'error': 'Could not send the message. Please try again.'};
    }
  }

  // ── AI discovery (search-parse / search-execute) ────────────────────────────
  @override
  Future<Map<String, dynamic>> searchParse(
    String query, {
    Map<String, dynamic>? locationHint,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'search-parse',
        body: {'query': query, 'parentLocationHint': ?locationHint},
      );
      final envelope = Map<String, dynamic>.from((res.data as Map?) ?? {});
      final parsed = envelope['result'];
      return parsed is Map ? Map<String, dynamic>.from(parsed) : envelope;
    } on FunctionException catch (e) {
      debugPrint('searchParse FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {
        'error': 'Could not understand that search (status ${e.status}).',
      };
    } catch (e) {
      debugPrint('searchParse failed: $e');
      return {'error': 'Could not run that search. Please try again.'};
    }
  }

  @override
  Future<Map<String, dynamic>> searchExecute(
    Map<String, dynamic> constraints, {
    Map<String, dynamic>? locationHint,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'search-execute',
        body: {'constraints': constraints, 'parentLocationHint': ?locationHint},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('searchExecute FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not run that search (status ${e.status}).'};
    } catch (e) {
      debugPrint('searchExecute failed: $e');
      return {'error': 'Could not run that search. Please try again.'};
    }
  }

  @override
  Future<Map<String, dynamic>> aiMatch(Map<String, dynamic> client) async {
    try {
      final res = await _db.functions.invoke(
        'ai-match',
        body: {'client': client},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('aiMatch FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not find matches (status ${e.status}).'};
    } catch (e) {
      debugPrint('aiMatch failed: $e');
      return {'error': 'Could not find matches. Please try again.'};
    }
  }

  @override
  Future<QueryIntent> parseChatQuery(String query) async {
    try {
      final res = await _db.functions.invoke(
        'chat-parse-query',
        body: {'query': query},
      );
      final data = Map<String, dynamic>.from((res.data as Map?) ?? {});
      if (data['error'] != null) {
        return const QueryIntent(intentType: QueryIntentType.other);
      }
      return QueryIntent.fromJson(data);
    } catch (e) {
      debugPrint('parseChatQuery failed: $e');
      return const QueryIntent(intentType: QueryIntentType.other);
    }
  }

  @override
  Future<List<ProviderMatch>> searchProviders(
    QueryIntent intent, {
    double? originLat,
    double? originLng,
  }) async {
    // Retrieval is CODE: fetch the market, then apply the hard gates in
    // ProviderMatcher over real rows (verificationStatus drives the safety gate).
    final data = await getProgramsOrThrow();
    // Gate inputs are GROUNDED from real columns in _mapProgram — never fabricated
    // here (fabricating them made G4/G5/G7 run on invented data).
    final services =
        data.whereType<Map>().map((p) => Map<String, dynamic>.from(p)).toList();
    // No hardcoded origin: without a KNOWN client location the distance gate
    // must not fire (otherwise a default radius wrongly excludes every listing
    // that isn't near an assumed city). Distance is only computed/gated when a
    // real origin is passed in.
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
    try {
      final res = await _db.functions.invoke(
        'chat-answer',
        body: {
          'question': question,
          'intent_type': intentType.wire,
          'rows': rows.map((r) => r.toRow()).toList(),
          'policy': ?policyText,
          'history': history,
        },
      );
      final data = Map<String, dynamic>.from((res.data as Map?) ?? {});
      if (data['error'] != null) return {'error': data['error'].toString()};
      return {
        'text': (data['text'] ?? '').toString(),
        'provider_ids':
            (data['provider_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
      };
    } on FunctionException catch (e) {
      debugPrint('answerChat FunctionException: ${e.status}');
      return {
        'error': 'The assistant is unavailable right now (status ${e.status}).',
      };
    } catch (e) {
      debugPrint('answerChat failed: $e');
      return {
        'error': 'The assistant is unavailable right now. Please try again.',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> askAssistant(
    List<Map<String, String>> messages,
  ) async {
    try {
      // ai-chat routes through ai-gateway (feature="assistant"); never a direct
      // model call. Pass the running history as {role, content}.
      final res = await _db.functions.invoke(
        'ai-chat',
        body: {'messages': messages},
      );
      final data = Map<String, dynamic>.from((res.data as Map?) ?? {});
      if (data['error'] != null) return {'error': data['error'].toString()};
      final text = (data['text'] ?? '').toString().trim();
      if (text.isEmpty) {
        return {'error': 'The assistant did not return a reply. Try again.'};
      }
      return {'text': text};
    } on FunctionException catch (e) {
      debugPrint('askAssistant FunctionException: ${e.status}');
      return {
        'error': 'The assistant is unavailable right now (status ${e.status}).',
      };
    } catch (e) {
      debugPrint('askAssistant failed: $e');
      return {
        'error': 'The assistant is unavailable right now. Please try again.',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> draftMessage(
    Map<String, dynamic> payload,
  ) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) {
        return {'error': 'Only a coach can draft replies.'};
      }
      final body = <String, dynamic>{
        'providerId': providerId,
        'threadContext': payload['threadContext'] ?? const [],
        if (payload['intent'] != null) 'intent': payload['intent'],
        if (payload['childFirstName'] != null)
          'childFirstName': payload['childFirstName'],
        if (payload['bookingContext'] != null)
          'bookingContext': payload['bookingContext'],
      };
      final res = await _db.functions.invoke('message-draft', body: body);
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('draftMessage FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not draft a reply (status ${e.status}).'};
    } catch (e) {
      debugPrint('draftMessage failed: $e');
      return {'error': 'Could not draft a reply. Please try again.'};
    }
  }

  @override
  Future<String?> upsertParentUpdateDraft(Map<String, dynamic> update) async {
    try {
      final providerId = await _currentProviderId();
      if (providerId == null) return null;
      final fields = <String, dynamic>{
        'provider_id': providerId,
        if (_isUuid(update['sessionNoteId']))
          'session_note_id': update['sessionNoteId'],
        if (_isUuid(update['bookingId'])) 'booking_id': update['bookingId'],
        if (_isUuid(update['childId'])) 'child_id': update['childId'],
        'summary_body': update['summaryBody'] ?? '',
        'skills_worked':
            (update['skillsWorked'] as List?)?.cast<String>() ?? <String>[],
        'progress_signal': update['progressSignal'] ?? '',
        'practice_suggestions':
            (update['practiceSuggestions'] as List?)?.cast<String>() ??
            <String>[],
        'encouragement': update['encouragement'] ?? '',
      };
      final id = update['id'];
      if (_isUuid(id)) {
        // Don't touch status on update — autosave must never revert an approval.
        await _db.from('parent_updates').update(fields).eq('id', id);
        return id.toString();
      }
      final inserted = await _db
          .from('parent_updates')
          .insert({...fields, 'status': 'draft'})
          .select('id')
          .single();
      return (inserted as Map)['id']?.toString();
    } on PostgrestException catch (e) {
      debugPrint('upsertParentUpdateDraft failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> approveParentUpdate(String id) async {
    try {
      final updated = await _db
          .from('parent_updates')
          .update({
            'status': 'approved',
            'approved_by': _uid,
            'approved_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Map<String, dynamic>.from(updated as Map);
    } on PostgrestException catch (e) {
      debugPrint('approveParentUpdate failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> sendParentUpdate(String id) async {
    try {
      final res = await _db.functions.invoke(
        'parent-update-send',
        body: {'parentUpdateId': id},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('sendParentUpdate FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not send the update (status ${e.status}).'};
    } catch (e) {
      debugPrint('sendParentUpdate failed: $e');
      return {'error': 'Could not send the update. Please try again.'};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getParentUpdatesForChild(
    String childId,
  ) async {
    try {
      final uid = _uid;
      if (uid == null || !_isUuid(childId)) return [];
      // Defense in depth on top of RLS: confirm the caller actually guards this
      // child before querying, then constrain to that child's SENT rows only.
      final child = await _db
          .from('athletes')
          .select('id')
          .eq('id', childId)
          .eq('parent_id', uid)
          .maybeSingle();
      if (child == null) return [];
      final rows = await _db
          .from('parent_updates')
          .select(
            'id, child_id, summary_body, skills_worked, progress_signal, practice_suggestions, encouragement, status, sent_at, created_at',
          )
          .eq('child_id', childId)
          .eq('status', 'sent')
          .order('created_at', ascending: false);
      return (rows as List).map((r) => _mapParentUpdate(r as Map)).toList();
    } catch (e) {
      debugPrint('getParentUpdatesForChild failed: $e');
      return [];
    }
  }

  Map<String, dynamic> _mapParentUpdate(Map row) => {
    '_id': row['id'],
    'childId': row['child_id'],
    'summaryBody': row['summary_body'] ?? '',
    'skillsWorked': _toList(row['skills_worked']),
    'progressSignal': row['progress_signal'] ?? '',
    'practiceSuggestions': _toList(row['practice_suggestions']),
    'encouragement': row['encouragement'] ?? '',
    'status': row['status'],
    'sentAt': row['sent_at'],
    'createdAt': row['created_at'],
  };

  // ── Outcome-first: goals, plans, proposals, digests (Prompts 1/2/3/5) ──────
  Map<String, dynamic> _mapGoal(Map row) => {
    '_id': row['id'],
    'athleteId': row['athlete_id'],
    'createdBy': row['created_by'],
    'outcomeText': row['outcome_text'] ?? '',
    'headline': row['headline'] ?? '',
    'outcomeType': row['outcome_type'],
    'sport': row['sport'],
    'targetDate': row['target_date'],
    'budgetMonthlyCents': row['budget_monthly_cents'],
    'constraints': row['constraints'] is Map
        ? Map<String, dynamic>.from(row['constraints'] as Map)
        : <String, dynamic>{},
    'status': row['status'],
    'createdAt': row['created_at'],
  };

  Map<String, dynamic> _mapPlan(Map row) => {
    '_id': row['id'],
    'goalId': row['goal_id'],
    'title': row['title'] ?? '',
    'phases': _toList(row['phases']),
    'currentPhaseIndex': row['current_phase_index'] ?? 0,
    'status': row['status'],
    'conciergeNote': row['concierge_note'],
    'conciergeCheckedAt': row['concierge_checked_at'],
    'createdAt': row['created_at'],
  };

  Map<String, dynamic> _mapProposal(Map row) {
    final prog = row['programs'];
    final prov = row['providers'];
    return {
      '_id': row['id'],
      'planId': row['plan_id'],
      'proposalType': row['proposal_type'],
      'serviceId': row['service_id'],
      'providerId': row['provider_id'],
      'reasonText': row['reason_text'] ?? '',
      'rank': row['rank'] ?? 0,
      'status': row['status'],
      'resultingBookingId': row['resulting_booking_id'],
      'createdAt': row['created_at'],
      // Joined facts (grounded): the program in the SAME UI shape the booking
      // flow + cards consume, and the provider's business identity.
      'program': prog is Map ? _mapProgram(prog) : null,
      'provider': prov is Map
          ? {
              '_id': prov['id'],
              'businessName': prov['business_name'],
              'verificationStatus': prov['verification_status'],
              'sports': _toList(prov['sports']),
              'backgroundCheckCompletedAt':
                  prov['background_check_completed_at'],
            }
          : null,
    };
  }

  Map<String, dynamic> _mapDigest(Map row) => {
    '_id': row['id'],
    'planId': row['plan_id'],
    'athleteId': row['athlete_id'],
    'body': row['body'] ?? '',
    'sessionsCounted': row['sessions_counted'] ?? 0,
    'sources': row['sources'] is Map
        ? Map<String, dynamic>.from(row['sources'] as Map)
        : <String, dynamic>{},
    'createdAt': row['created_at'],
  };

  @override
  Future<Map<String, dynamic>?> getActiveGoal(
    String athleteId, {
    String? sport,
  }) async {
    try {
      if (!_isUuid(athleteId)) return null;
      var q = _db
          .from('athlete_goals')
          .select()
          .eq('athlete_id', athleteId)
          .eq('status', 'active');
      if (sport != null && sport.isNotEmpty) q = q.eq('sport', sport);
      final rows = await q.order('created_at', ascending: false).limit(1);
      final list = rows as List;
      return list.isEmpty ? null : _mapGoal(list.first as Map);
    } catch (e) {
      debugPrint('getActiveGoal failed: $e');
      return null;
    }
  }

  @override
  Future<String?> createGoal(Map<String, dynamic> goal) async {
    try {
      final uid = _uid;
      final athleteId = _extractId(goal['athleteId']);
      if (uid == null || !_isUuid(athleteId)) return null;
      final constraints = goal['constraints'] is Map
          ? Map<String, dynamic>.from(goal['constraints'] as Map)
          : <String, dynamic>{};
      final targetDate = goal['targetDate']?.toString();
      final inserted = await _db
          .from('athlete_goals')
          .insert({
            'athlete_id': athleteId,
            'created_by': uid, // RLS WITH CHECK: created_by = auth.uid()
            'outcome_text': (goal['outcomeText'] ?? '').toString(),
            if ((goal['headline'] ?? '').toString().trim().isNotEmpty)
              'headline': (goal['headline']).toString().trim(),
            'outcome_type': goal['outcomeType'] ?? 'other',
            'sport': goal['sport'] ?? 'General',
            if (targetDate != null && targetDate.length >= 10)
              'target_date': targetDate.substring(0, 10),
            if (goal['budgetMonthlyCents'] is int)
              'budget_monthly_cents': goal['budgetMonthlyCents'],
            'constraints': constraints,
            'status': 'active',
          })
          .select('id')
          .single();
      return (inserted as Map)['id']?.toString();
    } on PostgrestException catch (e) {
      debugPrint('createGoal failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('createGoal failed: $e');
      return null;
    }
  }

  @override
  Future<String> formulateGoalHeadline(
    String rawOutcome, {
    String? sport,
  }) async {
    // AI headline via the gateway-backed `goal-formulate` Edge Function. On any
    // failure (including before it's deployed) fall back to the SAME local,
    // grounded truncation — mirrors the parseChatQuery/answerChat try/catch.
    try {
      final res = await _db.functions.invoke(
        'goal-formulate',
        body: {'outcome': rawOutcome, 'sport': ?sport},
      );
      final data = Map<String, dynamic>.from((res.data as Map?) ?? {});
      final headline = (data['headline'] ?? '').toString().trim();
      if (headline.isNotEmpty) return headline;
      return _localHeadline(rawOutcome);
    } on FunctionException catch (e) {
      debugPrint('formulateGoalHeadline FunctionException: ${e.status}');
      return _localHeadline(rawOutcome);
    } catch (e) {
      debugPrint('formulateGoalHeadline failed: $e');
      return _localHeadline(rawOutcome);
    }
  }

  // Local, GROUNDED truncation fallback for [formulateGoalHeadline] — only ever
  // removes words the parent typed (a leading filler opener, a trailing
  // rationale, and an overflow tail); never injects a sport/team/date/level not
  // in the input. This is byte-for-byte the SAME grounded pipeline as
  // MockRepository._headlineFromOutcome, so both fallbacks agree on any input.
  String _localHeadline(String raw) {
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

  @override
  Future<Map<String, dynamic>?> getPlanForGoal(String goalId) async {
    try {
      if (!_isUuid(goalId)) return null;
      final rows = await _db
          .from('development_plans')
          .select()
          .eq('goal_id', goalId)
          .order('created_at', ascending: false)
          .limit(1);
      final list = rows as List;
      return list.isEmpty ? null : _mapPlan(list.first as Map);
    } catch (e) {
      debugPrint('getPlanForGoal failed: $e');
      return null;
    }
  }

  @override
  Future<String?> createPlan(Map<String, dynamic> plan) async {
    try {
      final goalId = _extractId(plan['goalId']);
      if (!_isUuid(goalId)) return null;
      final phases = plan['phases'] is List ? plan['phases'] as List : const [];
      final inserted = await _db
          .from('development_plans')
          .insert({
            'goal_id': goalId,
            'title': (plan['title'] ?? 'Development plan').toString(),
            'phases': phases,
            'current_phase_index': plan['currentPhaseIndex'] ?? 0,
            'status': plan['status'] ?? 'active',
          })
          .select('id')
          .single();
      return (inserted as Map)['id']?.toString();
    } on PostgrestException catch (e) {
      debugPrint('createPlan failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('createPlan failed: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProposals(
    String planId, {
    String status = 'proposed',
  }) async {
    try {
      if (!_isUuid(planId)) return [];
      final rows = await _db
          .from('plan_proposals')
          .select(
            '*, programs(*, providers(business_name, verification_status, background_check_completed_at)), '
            'providers(id, business_name, verification_status, sports, background_check_completed_at)',
          )
          .eq('plan_id', planId)
          .eq('status', status)
          .order('rank');
      return (rows as List).map((r) => _mapProposal(r as Map)).toList();
    } catch (e) {
      debugPrint('getProposals failed: $e');
      return [];
    }
  }

  @override
  Future<bool> updateProposalStatus(String proposalId, String status) async {
    try {
      if (!_isUuid(proposalId)) return false;
      // RLS + sporve_plan_proposals_guard pin parents to a status-only change,
      // and only to accepted/declined. responded_at is stamped by the trigger.
      await _db
          .from('plan_proposals')
          .update({'status': status})
          .eq('id', proposalId);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('updateProposalStatus failed: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> setBookingProposal(String bookingId, String proposalId) async {
    try {
      if (!_isUuid(bookingId) || !_isUuid(proposalId)) return false;
      await _db
          .from('bookings')
          .update({'plan_proposal_id': proposalId})
          .eq('id', bookingId);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('setBookingProposal failed: ${e.message}');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getLatestDigest(String planId) async {
    try {
      if (!_isUuid(planId)) return null;
      final rows = await _db
          .from('progress_digests')
          .select()
          .eq('plan_id', planId)
          .order('created_at', ascending: false)
          .limit(1);
      final list = rows as List;
      return list.isEmpty ? null : _mapDigest(list.first as Map);
    } catch (e) {
      debugPrint('getLatestDigest failed: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> generateProposals(String planId) async {
    try {
      final res = await _db.functions.invoke(
        'generate-proposals',
        body: {'plan_id': planId},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('generateProposals FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not refresh suggestions (status ${e.status}).'};
    } catch (e) {
      debugPrint('generateProposals failed: $e');
      return {'error': 'Could not refresh suggestions. Please try again.'};
    }
  }

  @override
  Future<Map<String, dynamic>> planProgress(String planId) async {
    try {
      final res = await _db.functions.invoke(
        'plan-progress',
        body: {'plan_id': planId},
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? {});
    } on FunctionException catch (e) {
      debugPrint('planProgress FunctionException: ${e.status}');
      final det = e.details;
      if (det is Map && det['error'] != null) {
        return {'error': det['error'].toString()};
      }
      return {'error': 'Could not check progress (status ${e.status}).'};
    } catch (e) {
      debugPrint('planProgress failed: $e');
      return {'error': 'Could not check progress. Please try again.'};
    }
  }

  // ── Profiles ──────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final uid = _uid;
      if (uid == null) return {};
      final row = await _db
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return row == null ? {} : _mapUserProfile(row);
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return {};
    }
  }

  @override
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _db
          .from('profiles')
          .update({
            if (profile['firstName'] != null)
              'first_name': profile['firstName'],
            if (profile['lastName'] != null) 'last_name': profile['lastName'],
            if (profile['email'] != null) 'email': profile['email'],
            if (profile['phoneNumber'] != null)
              'phone_number': profile['phoneNumber'],
            if (profile['preferredSports'] != null)
              'preferred_sports': profile['preferredSports'],
            if (profile['profileImage'] != null)
              'profile_image': profile['profileImage'],
          })
          .eq('id', uid);
    } catch (e) {
      debugPrint('saveUserProfile failed: $e');
      rethrow; // let the caller surface a real error
    }
  }

  @override
  Future<Map<String, dynamic>> getProviderProfile() async {
    try {
      final uid = _uid;
      if (uid == null) return {};
      final row = await _db
          .from('providers')
          .select()
          .eq('owner_id', uid)
          .maybeSingle();
      return row == null ? {} : _mapProviderProfile(row);
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return {};
    }
  }

  @override
  Future<void> saveProviderProfile(Map<String, dynamic> profile) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      // Only the fields the caller actually provided.
      final fields = <String, dynamic>{
        if (profile['businessName'] != null)
          'business_name': profile['businessName'],
        if (profile['bio'] != null) 'bio': profile['bio'],
        if (profile['sports'] != null) 'sports': profile['sports'],
        if (profile['location'] != null) 'location': profile['location'],
        // `status`, `verification_status` and the stripe_* columns are NOT sent
        // from the client — they are server-controlled by the
        // enforce_provider_trust trigger. `status` is DERIVED from
        // onboarding_completed (completing onboarding lists the provider); the
        // 'verified' trust badge is admin/service-role only. So a provider can
        // never self-approve or self-verify.
        if (profile['onboardingCompleted'] != null)
          'onboarding_completed': profile['onboardingCompleted'],
      };
      // UPDATE the existing provider row (the edit case) — a partial edit must
      // NOT require business_name. Only INSERT a new row when none exists yet
      // (e.g. onboarding), where business_name is mandatory.
      final updated = await _db
          .from('providers')
          .update(fields)
          .eq('owner_id', uid)
          .select('id');
      if ((updated as List).isEmpty) {
        await _db.from('providers').insert({
          'owner_id': uid,
          'business_name': profile['businessName'] ?? 'My Academy',
          ...fields,
        });
      }
    } catch (e) {
      debugPrint('saveProviderProfile failed: $e');
      rethrow; // let the caller surface a real error
    }
  }

  // ── Athletes ──────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getAthletes() async {
    try {
      final rows = await _db.from('athletes').select();
      return (rows as List).map((r) => _mapAthlete(r as Map)).toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<String?> addAthlete(Map<String, dynamic> athlete) async {
    try {
      final uid = _uid;
      if (uid == null) return null;
      final dob = athlete['dateOfBirth']?.toString();
      final skill = athlete['skillLevel']?.toString();
      final inserted = await _db
          .from('athletes')
          .insert({
            'parent_id': uid, // RLS: parent owns the child
            'first_name': athlete['firstName'],
            'last_name': athlete['lastName'],
            if (dob != null && dob.length >= 10)
              'date_of_birth': dob.substring(0, 10),
            if (athlete['gender'] != null) 'gender': athlete['gender'],
            // Self-assessed level chip (§7) — one of beginner/developing/
            // intermediate/advanced; column is nullable so omit when unset.
            if (skill != null && skill.isNotEmpty) 'skill_level': skill,
            'parent_consent': true,
            'consent_at': DateTime.now().toUtc().toIso8601String(),
            'consent_version': 'v1',
          })
          .select('id')
          .single();
      return inserted['id']?.toString();
    } catch (e) {
      debugPrint('addAthlete failed: $e');
      return null;
    }
  }

  @override
  Future<void> saveAthletes(List<dynamic> athletes) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      for (final a in athletes) {
        if (a is! Map) continue;
        final row = _athleteToRow(a, uid);
        // Existing rows (real uuid) update; new rows insert under this parent.
        if (_isUuid(a['_id'])) {
          await _db.from('athletes').upsert(row);
        } else {
          await _db.from('athletes').insert(row);
        }
      }
    } catch (e) {
      debugPrint('SupabaseRepository write failed: $e');
    }
  }

  // ── Conversations & messages ──────────────────────────────────────────────
  // Real chat needs conversation rows keyed by searcher/provider profile ids,
  // which the current mock chat shape doesn't carry. Reads are wired; writes are
  // safe no-ops for now (ChatProvider keeps its in-session copy). Full chat
  // persistence is a follow-up, not part of #19's data flip.
  Future<List<dynamic>> _fetchConversations() async {
    final rows = await _db
        .from('conversations')
        .select()
        .order('last_message_at', ascending: false);
    return (rows as List)
        .map(
          (r) => {
            '_id': (r as Map)['id'],
            'programId': r['program_id'],
            'participants': [
              {'_id': r['searcher_id'], 'role': 'searcher'},
              {'_id': r['provider_id'], 'role': 'provider'},
            ],
            'lastMessage': r['last_message'] == null
                ? null
                : {'text': r['last_message']},
          },
        )
        .toList();
  }

  @override
  Future<List<dynamic>> getConversations() async {
    try {
      return await _fetchConversations();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<List<dynamic>> getConversationsOrThrow() => _fetchConversations();

  @override
  Future<void> saveConversations(List<dynamic> conversations) async {}

  @override
  Future<Map<String, dynamic>?> ensureProviderConversation({
    required String providerOwnerId,
    String? programId,
    String? providerName,
  }) async {
    final uid = _uid;
    if (uid == null || !_isUuid(providerOwnerId) || uid == providerOwnerId) {
      return null;
    }
    try {
      final result = await _db.rpc(
        'ensure_provider_conversation',
        params: {
          'p_provider_owner_id': providerOwnerId,
          'p_program_id': _isUuid(programId) ? programId : null,
        },
      );
      if (result is! Map) return null;
      return {
        '_id': result['id'],
        'programId': result['program_id'],
        'participants': [
          {'_id': result['searcher_id'], 'role': 'searcher'},
          {
            '_id': result['provider_id'],
            'role': 'provider',
            'firstName': providerName ?? 'Coach',
          },
        ],
        'lastMessage': result['last_message'] == null
            ? null
            : {'text': result['last_message']},
      };
    } on PostgrestException catch (e) {
      debugPrint('ensureProviderConversation failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<List<dynamic>> getMessages(String conversationId) async {
    try {
      if (!_isUuid(conversationId)) return [];
      final rows = await _db
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at');
      return (rows as List)
          .map(
            (r) => {
              '_id': (r as Map)['id'],
              'conversationId': r['conversation_id'],
              'text': r['body'],
              'senderId': r['sender_id'],
              'createdAt': r['created_at'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<void> saveMessages(
    String conversationId,
    List<dynamic> messages,
  ) async {
    // Deprecated: chat is append-only now. Use postMessage() for new messages;
    // this wholesale-replace no-op stays only for interface compatibility.
  }

  @override
  Future<Map<String, dynamic>?> postMessage(
    String conversationId,
    String body,
  ) async {
    try {
      if (!_isUuid(conversationId) || body.trim().isEmpty) return null;
      final inserted = await _db
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': _uid,
            'body': body.trim(),
          })
          .select()
          .single();
      final m = inserted as Map;
      // Best-effort: bump the conversation's last-message preview.
      await _db
          .from('conversations')
          .update({
            'last_message': body.trim(),
            'last_message_at': m['created_at'],
          })
          .eq('id', conversationId);
      return {
        '_id': m['id'],
        'conversationId': m['conversation_id'],
        'text': m['body'],
        'senderId': m['sender_id'],
        'createdAt': m['created_at'],
      };
    } on PostgrestException catch (e) {
      debugPrint('postMessage failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<void Function()> subscribeMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  ) async {
    final channel = _db.channel('messages:$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final r = payload.newRecord;
            onMessage({
              '_id': r['id'],
              'conversationId': r['conversation_id'],
              'text': r['body'],
              'senderId': r['sender_id'],
              'createdAt': r['created_at'],
            });
          },
        )
        .subscribe();
    return () async {
      await _db.removeChannel(channel);
    };
  }

  // ── Teams ─────────────────────────────────────────────────────────────────
  @override
  Future<List<dynamic>> getTeams() async {
    try {
      final rows = await _db.from('teams').select('*, team_athletes(*)');
      return (rows as List).map((r) {
        final m = r as Map;
        final roster = _toList(m['team_athletes']).map((ta) {
          final t = ta as Map;
          return {
            '_id': t['athlete_id'],
            // Denormalized name (see team_athlete_name migration); blank until
            // applied — never read the minors-only athletes table here.
            'fullName': t['athlete_first_name']?.toString() ?? '',
            'jerseyNumber': t['jersey_number'],
            'isAvailable': t['is_available'] ?? true,
            'isPaid': t['is_paid'] ?? false,
          };
        }).toList();
        return {
          '_id': m['id'],
          'name': m['name'],
          'sport': m['sport'],
          'roster': roster,
        };
      }).toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<void> saveTeams(List<dynamic> teams) async {}

  // ── Notifications ─────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getNotificationPrefs() async {
    final data = _local.read('notification_prefs');
    return data == null ? {} : Map<String, dynamic>.from(data);
  }

  @override
  Future<void> saveNotificationPrefs(Map<String, dynamic> prefs) async =>
      _local.write('notification_prefs', prefs);

  @override
  Future<List<dynamic>> getNotifications() async {
    try {
      final rows = await _db
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (r) => {
              '_id': (r as Map)['id'],
              'title': r['title'],
              'message': r['message'],
              'isRead': r['read'] ?? false,
              'createdAt': r['created_at'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return [];
    }
  }

  @override
  Future<void> saveNotifications(List<dynamic> notifications) async {}

  @override
  Future<void> savePushToken(String token, {String platform = 'web'}) async {
    try {
      final uid = _uid;
      if (uid == null || token.isEmpty) return;
      await _db.from('push_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      debugPrint('savePushToken failed: $e');
    }
  }

  // ── Favorites (local; no dedicated table yet) ─────────────────────────────
  @override
  Future<List<String>> getFavorites() async {
    final favs = _local.read('favorites');
    return favs == null ? <String>[] : List<String>.from(favs);
  }

  @override
  Future<void> saveFavorites(List<String> favorites) async =>
      _local.write('favorites', favorites);

  // ── Reverse mappers: UI map (camelCase) → DB row (snake_case) ─────────────
  Future<String?> _currentProviderId() async {
    try {
      final uid = _uid;
      if (uid == null) return null;
      final row = await _db
          .from('providers')
          .select('id')
          .eq('owner_id', uid)
          .maybeSingle();
      return (row as Map?)?['id']?.toString();
    } catch (e) {
      debugPrint('SupabaseRepository read failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _programToRow(Map p, String providerId) {
    final addr = p['address'];
    final loc = p['location'];
    final coords = (loc is Map && loc['coordinates'] is List)
        ? loc['coordinates'] as List
        : const [];
    return {
      if (_isUuid(p['_id'])) 'id': p['_id'],
      'provider_id': providerId,
      'title': p['title'] ?? 'Untitled',
      'description': p['description'],
      'sport_type': p['sportType'] ?? 'Soccer',
      if (p['programType'] != null) 'program_type': p['programType'],
      'skill_level': p['skillLevel'],
      'age_group': p['ageGroup'],
      if (p['language'] != null) 'language': p['language'],
      'cover_image': p['coverImage'],
      if (p['gallery'] != null) 'gallery': p['gallery'],
      if (p['whatsIncluded'] != null) 'whats_included': p['whatsIncluded'],
      'price': p['price'] ?? 0,
      if (p['currency'] != null) 'currency': p['currency'],
      if (p['pricingModel'] != null) 'pricing_model': p['pricingModel'],
      'max_capacity': p['maxCapacity'] ?? 0,
      'enrolled_count': p['enrolledCount'] ?? 0,
      if (coords.length == 2) 'longitude': coords[0],
      if (coords.length == 2) 'latitude': coords[1],
      if (addr is Map) 'address_line1': addr['line1'],
      if (addr is Map) 'city': addr['city'],
      if (addr is Map) 'state': addr['state'],
      if (addr is Map) 'zip': addr['zip'],
      if (addr is Map) 'country': addr['country'],
      if (p['cancellationPolicy'] != null)
        'cancellation_policy': p['cancellationPolicy'],
      'minimum_age': p['minimumAge'],
      'maximum_age': p['maximumAge'],
      'is_featured': p['isFeatured'] ?? false,
      'status': p['status'] ?? 'draft',
    };
  }

  Map<String, dynamic> _sessionToRow(Map s) {
    String? dateOnly(dynamic v) => v?.toString().substring(0, 10);
    return {
      if (_isUuid(s['_id'])) 'id': s['_id'],
      'program_id': _extractId(s['programId']),
      'title': s['title'],
      'start_date': dateOnly(s['startDate'] ?? s['date']),
      'end_date': dateOnly(s['endDate']),
      'start_time': s['startTime'],
      'end_time': s['endTime'],
      'timezone': s['timezone'],
      'address': s['address'],
    };
  }

  Map<String, dynamic> _athleteToRow(Map a, String parentId) {
    const validGenders = {'male', 'female', 'other', 'prefer_not_to_say'};
    String? dob = a['dateOfBirth']?.toString();
    if (dob != null && dob.length >= 10) dob = dob.substring(0, 10);
    final gender = a['gender']?.toString();
    // The onboarding flow stores the child's name as `fullName`; derive
    // first/last from it so the real name is persisted (not a placeholder).
    final full = (a['fullName'] ?? '').toString().trim();
    final firstFromFull = full.isEmpty
        ? null
        : full.split(RegExp(r'\s+')).first;
    final lastFromFull = full.contains(' ')
        ? full.substring(full.indexOf(' ') + 1).trim()
        : null;
    return {
      if (_isUuid(a['_id'])) 'id': a['_id'],
      'parent_id': parentId,
      // REAL entered name only (UI validates non-empty); no 'Athlete' fallback.
      'first_name': a['firstName'] ?? firstFromFull,
      'last_name': a['lastName'] ?? lastFromFull,
      'date_of_birth': dob, // required real DOB (UI-validated); never defaulted
      if (gender != null && validGenders.contains(gender)) 'gender': gender,
      if (a['preferredSports'] != null)
        'preferred_sports': a['preferredSports'],
      // Written only when the parent entered it — null otherwise (no 'None').
      'medical_conditions': a['medicalConditions'],
      if (a['emergencyContact'] != null)
        'emergency_contact': a['emergencyContact'],
      'profile_image': a['profileImage'],
      // COPPA parental consent.
      if (a['parentConsent'] != null) 'parent_consent': a['parentConsent'],
      if (a['consentAt'] != null) 'consent_at': a['consentAt'],
      if (a['consentVersion'] != null) 'consent_version': a['consentVersion'],
    };
  }
}
