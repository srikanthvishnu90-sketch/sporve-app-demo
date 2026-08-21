import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';

/// Provider Model Rebuild — item #2 (family side): the three multi-booking
/// mechanisms that attach to a SERVICE and read the shared bookable inventory
/// — group seats, a recurring weekly claim, and prepaid pack credits. Thin
/// over [MultiBookingRepository] / [ServiceRepository]; every write follows
/// L-015 (honest null/false on failure, never a fake success — the VIEW must
/// act on it, not just this controller).
class MultiBookingController extends ChangeNotifier {
  MultiBookingController(this._repo);
  final AppRepository _repo;

  bool _loading = false;
  bool get loading => _loading;
  bool _error = false;
  bool get error => _error;
  String? _actionError;
  String? get actionError => _actionError;

  // The candidate slots for the service (from the shared availability ×
  // service multiplication). Read-only display data.
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> get slots => List.unmodifiable(_slots);

  // Group-slot roster, keyed "date|time", so seats-left is always the real
  // count (bookableSlots does not carry live occupancy in the mock — L-015:
  // never trust a stale seatsRemaining when the real count is one call away).
  final Map<String, List<Map<String, dynamic>>> _rosterBySlot = {};

  int _creditBalance = 0;
  int get creditBalance => _creditBalance;

  /// Loads bookable slots for [serviceId] over the next [days] days, plus the
  /// caller's prepaid credit balance for this service. Never throws.
  Future<void> load({
    required String providerId,
    required String serviceId,
    int days = 21,
  }) async {
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      final from = DateTime.now();
      final to = from.add(Duration(days: days));
      String iso(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      _slots = await _repo.bookableSlots(
        providerId: providerId,
        serviceId: serviceId,
        fromDate: iso(from),
        toDate: iso(to),
      );
      _creditBalance = await _repo.creditBalanceForService(serviceId);
      // Prime the roster (seats-left) for every candidate slot so the sheet
      // never shows a stale/optimistic capacity number.
      for (final slot in _slots) {
        final date = slot['date']?.toString();
        final time = slot['startTime']?.toString();
        if (date == null || time == null) continue;
        _rosterBySlot['$date|$time'] = await _repo.groupSlotRoster(
          serviceId: serviceId,
          slotDate: date,
          slotTime: time,
        );
      }
    } catch (e) {
      debugPrint('MultiBookingController.load failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Seats already held for [date]/[time] (0 when unknown / not yet loaded).
  int bookedCount(String date, String time) =>
      _rosterBySlot['$date|$time']?.length ?? 0;

  /// Claim one seat of a group slot. Returns the booking id, or null on a
  /// full slot / failure (L-015) — the caller shows a real error, never
  /// treats null as a silent no-op.
  Future<String?> claimGroupSeat({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  }) async {
    _actionError = null;
    try {
      final id = await _repo.claimGroupSeat(
        serviceId: serviceId,
        slotDate: slotDate,
        slotTime: slotTime,
        athleteId: athleteId,
        athleteFirstName: athleteFirstName,
        athleteAgeBand: athleteAgeBand,
      );
      if (id != null) {
        // Refresh the local seats-left count for this slot so the UI reflects
        // the claim immediately (no stale "seats left" after a successful tap).
        _rosterBySlot['$slotDate|$slotTime'] = await _repo.groupSlotRoster(
          serviceId: serviceId,
          slotDate: slotDate,
          slotTime: slotTime,
        );
        notifyListeners();
      }
      if (id == null) _actionError = 'That slot is no longer available.';
      return id;
    } on RepositoryActionException catch (e) {
      _actionError = e.message;
      debugPrint('MultiBookingController.claimGroupSeat blocked: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('MultiBookingController.claimGroupSeat failed: $e');
      _actionError = 'That slot could not be claimed. Please try again.';
      return null;
    }
  }

  /// Start a recurring weekly claim (the coach approves the generated
  /// occurrences later). Returns the new claim id, or null on failure.
  Future<String?> createRecurringClaim(Map<String, dynamic> claim) async {
    _actionError = null;
    try {
      final id = await _repo.createRecurringClaim(claim);
      if (id == null) _actionError = 'The recurring request is unavailable.';
      return id;
    } on RepositoryActionException catch (e) {
      _actionError = e.message;
      debugPrint(
        'MultiBookingController.createRecurringClaim blocked: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('MultiBookingController.createRecurringClaim failed: $e');
      _actionError =
          'The recurring request could not be sent. Please try again.';
      return null;
    }
  }

  /// Redeem one prepaid pack credit toward [slotDate]/[slotTime]. Returns the
  /// booking id, or null when there's no credit / the slot is full / failure.
  Future<String?> redeemPackCredit({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  }) async {
    _actionError = null;
    try {
      final id = await _repo.redeemPackCredit(
        serviceId: serviceId,
        slotDate: slotDate,
        slotTime: slotTime,
        athleteId: athleteId,
        athleteFirstName: athleteFirstName,
        athleteAgeBand: athleteAgeBand,
      );
      if (id != null) {
        _creditBalance = await _repo.creditBalanceForService(serviceId);
        _rosterBySlot['$slotDate|$slotTime'] = await _repo.groupSlotRoster(
          serviceId: serviceId,
          slotDate: slotDate,
          slotTime: slotTime,
        );
        notifyListeners();
      }
      if (id == null) {
        _actionError = 'No credit is available, or that slot just filled.';
      }
      return id;
    } on RepositoryActionException catch (e) {
      _actionError = e.message;
      debugPrint(
        'MultiBookingController.redeemPackCredit blocked: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('MultiBookingController.redeemPackCredit failed: $e');
      _actionError = 'The credit could not be redeemed. Please try again.';
      return null;
    }
  }
}
