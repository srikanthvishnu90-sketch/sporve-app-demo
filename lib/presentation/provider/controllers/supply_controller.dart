import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';

/// Provider Model Rebuild — Part 0 / item #1 state. The listing is dead. A coach
/// defines THREE things separately and the system multiplies them into bookable
/// inventory:
///   • SERVICE       — what they sell (price/capacity/duration, NO times).
///   • AVAILABILITY  — ONE weekly grid per coach (times) + buffer + vacation.
///   • LOCATION      — saved venues.
/// Because a service carries no times, changing Tuesday once (here) updates EVERY
/// service; creating a second service never re-asks for times. Thin over the
/// [ServiceRepository] / [ProviderAvailabilityRepository] / [LocationRepository]
/// facets of [AppRepository]; RLS scopes every read/write to the owning coach.
/// Every write returns bool so the view can surface honest failure (L-015).
class SupplyController extends ChangeNotifier {
  SupplyController(this._repo);
  final AppRepository _repo;

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> get services => List.unmodifiable(_services);

  // Weekly grid: rows of {dayOfWeek, startTime "HH:mm(:ss)", endTime}.
  List<Map<String, dynamic>> _availability = [];
  List<Map<String, dynamic>> get availability => List.unmodifiable(_availability);

  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> get locations => List.unmodifiable(_locations);

  int _bufferMinutes = 0;
  int get bufferMinutes => _bufferMinutes;
  String? _vacationUntil; // ISO yyyy-MM-dd or null
  String? get vacationUntil => _vacationUntil;

  List<String> _exceptions = [];
  List<String> get exceptions => List.unmodifiable(_exceptions);

  bool _loading = false;
  bool get loading => _loading;
  bool _error = false;
  bool get error => _error;
  bool _saving = false;
  bool get saving => _saving;

  Future<void> load() async {
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getMyServices(),
        _repo.getWeeklyAvailability(),
        _repo.getMyLocations(),
        _repo.getAvailabilitySettings(),
        _repo.getAvailabilityExceptions(),
      ]);
      _services = results[0] as List<Map<String, dynamic>>;
      _availability = results[1] as List<Map<String, dynamic>>;
      _locations = results[2] as List<Map<String, dynamic>>;
      final settings = results[3] as Map<String, dynamic>;
      _bufferMinutes = (settings['bufferMinutes'] as num?)?.toInt() ?? 0;
      _vacationUntil = settings['vacationUntil']?.toString();
      _exceptions = results[4] as List<String>;
    } catch (e) {
      debugPrint('SupplyController.load failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Services ────────────────────────────────────────────────────────────────
  /// Create ONE service. NO times are asked for — they live on the shared weekly
  /// availability. Returns true on success (and reloads).
  Future<bool> addService({
    required String serviceType, // private | group | camp | team_block
    required String title,
    String? sport,
    required int durationMinutes,
    required int priceCents,
    int capacity = 1,
    String? locationId,
    // Item #7 camp facets — only meaningful (and only sent) when
    // serviceType == 'camp'; the DB rejects them on any other type.
    String? startsOn, // yyyy-MM-dd
    String? endsOn, // yyyy-MM-dd
    String? dailyStartTime, // HH:mm:ss
    String? dailyEndTime, // HH:mm:ss
    String? ageBand,
    int? earlyBirdPriceCents,
    String? earlyBirdCutoff, // yyyy-MM-dd
    int? depositCents,
  }) async {
    _saving = true;
    notifyListeners();
    try {
      final id = await _repo.createService({
        'serviceType': serviceType,
        'title': title,
        'sport': sport,
        'durationMinutes': durationMinutes,
        'priceCents': priceCents,
        'capacity': capacity,
        'locationId': locationId,
        if (serviceType == 'camp') ...{
          'startsOn': startsOn,
          'endsOn': endsOn,
          'dailyStartTime': dailyStartTime,
          'dailyEndTime': dailyEndTime,
          'ageBand': ageBand,
          'earlyBirdPriceCents': earlyBirdPriceCents,
          'earlyBirdCutoff': earlyBirdCutoff,
          'depositCents': depositCents,
        },
      });
      if (id != null) await _reload();
      return id != null;
    } catch (e) {
      debugPrint('SupplyController.addService failed: $e');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> setServiceActive(String serviceId, bool active) async {
    final ok = await _repo.setServiceActive(serviceId, active);
    if (ok) {
      final i = _services.indexWhere((s) => s['_id'] == serviceId);
      if (i != -1) _services[i]['active'] = active;
      notifyListeners();
    }
    return ok;
  }

  // ── Weekly availability (ONE grid, shared by every service) ─────────────────
  /// Replace the whole weekly grid. [blocks] rows carry dayOfWeek + startTime +
  /// endTime ("HH:mm"). Returns true on success (and reloads the grid).
  Future<bool> saveWeeklyAvailability(List<Map<String, dynamic>> blocks) async {
    _saving = true;
    notifyListeners();
    try {
      final ok = await _repo.setWeeklyAvailability(blocks);
      if (ok) _availability = await _repo.getWeeklyAvailability();
      return ok;
    } catch (e) {
      debugPrint('SupplyController.saveWeeklyAvailability failed: $e');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> setBuffer(int minutes) async {
    // setAvailabilitySettings writes BOTH fields — pass the current vacation so
    // changing the buffer never silently clears an active vacation.
    final ok = await _repo.setAvailabilitySettings(
      bufferMinutes: minutes,
      vacationUntil: _vacationUntil,
    );
    if (ok) {
      _bufferMinutes = minutes;
      notifyListeners();
    }
    return ok;
  }

  /// Set (or clear, pass null) the vacation date. Returns true on success.
  Future<bool> setVacationUntil(String? iso) async {
    final ok = await _repo.setAvailabilitySettings(
      bufferMinutes: _bufferMinutes,
      vacationUntil: iso,
    );
    if (ok) {
      _vacationUntil = iso;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> addException(String iso, {String? reason}) async {
    final ok = await _repo.addAvailabilityException(iso, reason: reason);
    if (ok) {
      _exceptions = await _repo.getAvailabilityExceptions();
      notifyListeners();
    }
    return ok;
  }

  Future<bool> removeException(String iso) async {
    final ok = await _repo.removeAvailabilityException(iso);
    if (ok) {
      _exceptions = await _repo.getAvailabilityExceptions();
      notifyListeners();
    }
    return ok;
  }

  // ── Locations ───────────────────────────────────────────────────────────────
  Future<bool> addLocation({
    required String name,
    String? addressLine1,
    String? city,
    String? state,
    String? zip,
  }) async {
    _saving = true;
    notifyListeners();
    try {
      final id = await _repo.createLocation({
        'name': name,
        'addressLine1': addressLine1,
        'city': city,
        'state': state,
        'zip': zip,
      });
      if (id != null) _locations = await _repo.getMyLocations();
      return id != null;
    } catch (e) {
      debugPrint('SupplyController.addLocation failed: $e');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteLocation(String locationId) async {
    final ok = await _repo.deleteLocation(locationId);
    if (ok) {
      _locations = await _repo.getMyLocations();
      // A deleted venue un-pins services (DB SET NULL) — refresh them too.
      _services = await _repo.getMyServices();
      notifyListeners();
    }
    return ok;
  }

  /// Preview the multiplication for one service over the next [days] days — proves
  /// service × shared-availability × location − exceptions/vacation. Empty on fail.
  Future<List<Map<String, dynamic>>> previewSlots(
    String serviceId, {
    int days = 14,
  }) async {
    final now = DateTime.now();
    final to = now.add(Duration(days: days));
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final providerId = _services.firstWhere(
          (s) => s['_id'] == serviceId,
          orElse: () => const {},
        )['providerId']?.toString() ??
        '';
    return _repo.bookableSlots(
      providerId: providerId,
      serviceId: serviceId,
      fromDate: iso(now),
      toDate: iso(to),
    );
  }

  /// Coach-side: the mini-roster for ONE group slot — first name + age band only
  /// (L-005). [slotTime] MUST be the canonical bookable_slots start_time string
  /// (the same identity the family's claim used) so the roster matches the seats.
  Future<List<Map<String, dynamic>>> groupRoster({
    required String serviceId,
    required String slotDate,
    required String slotTime,
  }) {
    return _repo.groupSlotRoster(
      serviceId: serviceId,
      slotDate: slotDate,
      slotTime: slotTime,
    );
  }

  Future<void> _reload() async {
    _services = await _repo.getMyServices();
    _locations = await _repo.getMyLocations();
  }
}
