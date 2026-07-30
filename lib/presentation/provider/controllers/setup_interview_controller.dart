import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/data/sport_templates.dart';

/// One turn in the setup-interview thread (agent ⇄ coach).
class SetupMessage {
  const SetupMessage(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

/// Provider Model Rebuild — item #4. Onboarding as an AI INTERVIEW, not forms.
///
/// The agent asks 6–8 short questions, each answerable with a tappable chip
/// (pre-filled from the sport TEMPLATE) OR free text, then PROPOSES ONE bundle
/// (services + one shared weekly availability + policies) the coach confirms or
/// edits. Under-10-min budget: sensible template defaults are pre-selected so the
/// coach can reach a first service in a handful of taps.
///
/// GROUNDING (L-012 / L-016): every proposed value is either something the coach
/// stated OR a sport-template default, LABELED a suggestion. Nothing invents a
/// fact about THIS coach. The best-effort [AppRepository.refineSetupBundle] AI
/// call only parses messier free-text; on any failure the deterministic,
/// template-derived bundle stands.
///
/// CONFIRM PATH: [confirm] calls ONLY the existing item-#1 repo methods —
/// createLocation (optional) → setWeeklyAvailability (the ONE shared grid, never
/// a per-service calendar) → createService × N → saveCoachPolicies. No new
/// mutation path. Honest failure (L-015): any failed write stops and returns
/// false with a real error; it never fakes success.
class SetupInterviewController extends ChangeNotifier {
  SetupInterviewController(this._repo);
  final AppRepository _repo;

  // ── Thread + step ──────────────────────────────────────────────────────────
  final List<SetupMessage> _messages = [];
  List<SetupMessage> get messages => List.unmodifiable(_messages);

  // 0 sport · 1 kinds · 2 duration · 3 price · 4 availability · 5 location ·
  // 6 cancellation · 7 what-to-bring · 8 summary.
  int _step = 0;
  int get step => _step;
  static const int _summaryStep = 8;
  bool get atSummary => _step >= _summaryStep;

  // Free-text transcript fed to the best-effort AI extraction (grounding input).
  final List<Map<String, String>> _transcript = [];

  SportTemplate _template = SportTemplates.forSport(null);
  SportTemplate get template => _template;

  // ── Proposed bundle (editable on the summary) ───────────────────────────────
  String sport = '';
  bool offersPrivate = true;
  bool offersGroup = false;
  int durationMinutes = 60;
  int privatePriceCents = 6000;
  int groupPriceCents = 3000;
  int groupCapacity = 6;
  // The ONE shared weekly grid: rows of {dayOfWeek, startTime "HH:mm", endTime}.
  List<Map<String, dynamic>> availability = [];
  String locationName = '';
  String cancellationPolicy = '';
  String whatToBring = '';

  bool _refining = false;
  bool get refining => _refining;
  bool _submitting = false;
  bool get submitting => _submitting;
  bool _done = false;
  bool get done => _done;
  String? error;

  // ── Start ────────────────────────────────────────────────────────────────
  void start({String? sport}) {
    _messages
      ..clear()
      ..add(const SetupMessage(false,
          "Let's set up your coaching in a few quick questions — I'll suggest "
          "sensible defaults you can change. First: which sport do you coach?"));
    _transcript.clear();
    _step = 0;
    _refining = false;
    _submitting = false;
    _done = false;
    error = null;
    final s = (sport ?? '').trim();
    if (s.isNotEmpty) {
      // Pre-seed from a known sport but still confirm it as step 0.
      _applyTemplate(s);
    }
    notifyListeners();
  }

  void _applyTemplate(String sportName) {
    _template = SportTemplates.forSport(sportName);
    sport = _template.sport;
    final priv = _template.privateTemplate;
    final grp = _template.groupTemplate;
    if (priv != null) {
      durationMinutes = priv.durationMinutes;
      privatePriceCents = priv.priceMidCents;
    }
    if (grp != null) {
      groupPriceCents = grp.priceMidCents;
      groupCapacity = grp.capacity;
    }
    cancellationPolicy = _template.cancellationPolicy;
    whatToBring = _template.whatToBring;
    // Default the shared grid to the template's weekday-evening blocks.
    availability = _template.weekdayEvenings.map((b) => b.toBlock()).toList();
  }

  // ── Step 0: sport ──────────────────────────────────────────────────────────
  void answerSport(String value) {
    final v = value.trim();
    if (v.isEmpty || _step != 0) return;
    _applyTemplate(v);
    _record('Which sport?', v);
    _advance(v);
  }

  // ── Step 1: which service kinds ─────────────────────────────────────────────
  void answerKinds({required bool private, required bool group}) {
    if (_step != 1) return;
    offersPrivate = private || (!private && !group); // never zero services
    offersGroup = group;
    final label = offersPrivate && offersGroup
        ? 'Private + small-group'
        : offersGroup
            ? 'Small-group only'
            : '1-on-1 private';
    _record('Do you train 1-on-1, in small groups, or both?', label);
    _advance(label);
  }

  void answerKindsText(String text) {
    if (_step != 1) return;
    final q = text.toLowerCase();
    final grp = q.contains('group') || q.contains('team') || q.contains('clinic');
    final priv = q.contains('1') ||
        q.contains('one') ||
        q.contains('private') ||
        q.contains('individual') ||
        q.contains('both');
    answerKinds(private: priv || !grp, group: grp || q.contains('both'));
  }

  // ── Step 2: duration ─────────────────────────────────────────────────────────
  void answerDuration(int minutes) {
    if (_step != 2) return;
    durationMinutes = minutes.clamp(15, 240);
    _record('How long is a typical session?', '$durationMinutes min');
    _advance('$durationMinutes min');
  }

  void answerDurationText(String text) {
    if (_step != 2) return;
    final m = RegExp(r'(\d{2,3})').firstMatch(text.replaceAll(',', ''));
    answerDuration(m != null ? (int.tryParse(m.group(1)!) ?? durationMinutes) : durationMinutes);
  }

  // ── Step 3: price (the private price; group is template-derived) ────────────
  void answerPrice(int cents) {
    if (_step != 3) return;
    privatePriceCents = cents.clamp(1000, 50000);
    _record('What do you charge per private session?',
        _dollars(privatePriceCents));
    _advance(_dollars(privatePriceCents));
  }

  void answerPriceText(String text) {
    if (_step != 3) return;
    final m = RegExp(r'(\d{2,5})').firstMatch(text.replaceAll(RegExp(r'[\$,]'), ''));
    if (m != null) {
      final dollars = int.tryParse(m.group(1)!) ?? 0;
      answerPrice(dollars * 100);
    } else {
      answerPrice(privatePriceCents); // keep the template suggestion
    }
  }

  // ── Step 4: availability (chips toggle template block sets) ─────────────────
  void useWeekdayEvenings() {
    if (_step != 4) return;
    availability = _template.weekdayEvenings.map((b) => b.toBlock()).toList();
    _record('When are you generally available?', 'Weekday evenings');
    _advance('Weekday evenings');
  }

  void useWeekendMornings() {
    if (_step != 4) return;
    availability = _template.weekendMornings.map((b) => b.toBlock()).toList();
    _record('When are you generally available?', 'Weekend mornings');
    _advance('Weekend mornings');
  }

  void useBothTimes() {
    if (_step != 4) return;
    availability = [
      ..._template.weekdayEvenings.map((b) => b.toBlock()),
      ..._template.weekendMornings.map((b) => b.toBlock()),
    ];
    _record('When are you generally available?',
        'Weekday evenings + weekend mornings');
    _advance('Weekday evenings + weekend mornings');
  }

  // ── Step 5: location (optional) ─────────────────────────────────────────────
  void answerLocation(String value) {
    if (_step != 5) return;
    locationName = value.trim();
    final label = locationName.isEmpty ? 'Skipped for now' : locationName;
    _record('Where do you train?', label);
    _advance(label);
  }

  void skipLocation() => answerLocation('');

  // ── Step 6: cancellation policy ─────────────────────────────────────────────
  void answerCancellation(String value) {
    if (_step != 6) return;
    final v = value.trim();
    if (v.isNotEmpty) cancellationPolicy = v; // else keep template suggestion
    _record("What's your cancellation policy?", cancellationPolicy);
    _advance(v.isEmpty ? 'Use the suggested policy' : v);
  }

  void useTemplateCancellation() => answerCancellation('');

  // ── Step 7: what to bring → transitions to summary via finalize() ───────────
  Future<void> answerWhatToBring(String value) async {
    if (_step != 7) return;
    final v = value.trim();
    if (v.isNotEmpty) whatToBring = v; // else keep template suggestion
    _record('Anything athletes should bring?', whatToBring);
    _messages.add(SetupMessage(true, v.isEmpty ? 'Use the suggested list' : v));
    _step = _summaryStep;
    _messages.add(const SetupMessage(false,
        "Here's your setup — every value is your answer or a typical default you "
        'can edit. Confirm and your first service goes live (your background '
        'check keeps running in the background).'));
    notifyListeners();
    await _refine();
  }

  Future<void> useTemplateWhatToBring() => answerWhatToBring('');

  // ── Best-effort AI refinement (never blocks; grounded) ───────────────────────
  Future<void> _refine() async {
    _refining = true;
    notifyListeners();
    try {
      final bundle = await _repo.refineSetupBundle(
        sport: sport,
        transcript: List<Map<String, String>>.from(_transcript),
        template: _templatePayload(),
      );
      if (bundle != null) _applyRefinedBundle(bundle);
    } catch (e) {
      debugPrint('SetupInterviewController._refine failed: $e');
      // Keep the deterministic template bundle — honest, never fabricated.
    } finally {
      _refining = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _templatePayload() => {
        'sport': sport,
        'services': [
          {
            'service_type': 'private',
            'title': (_template.privateTemplate ?? _template.services.first)
                .titleFor(sport),
            'duration_minutes': durationMinutes,
            'price_cents': privatePriceCents,
            'capacity': 1,
          },
          {
            'service_type': 'group',
            'title': (_template.groupTemplate ?? _template.services.last)
                .titleFor(sport),
            'duration_minutes': durationMinutes,
            'price_cents': groupPriceCents,
            'capacity': groupCapacity,
          },
        ],
        'availability': availability
            .map((b) => {
                  'day_of_week': b['dayOfWeek'],
                  'start': b['startTime'],
                  'end': b['endTime'],
                })
            .toList(),
        'policies': {
          'cancellation': cancellationPolicy,
          'what_to_bring': whatToBring,
        },
      };

  /// Apply the grounded AI bundle over the template defaults. Only clamps into
  /// sane ranges; the server already hardened it, this is defense-in-depth. Never
  /// changes which service KINDS the coach chose (that was an explicit answer).
  void _applyRefinedBundle(Map<String, dynamic> bundle) {
    final services = bundle['services'];
    if (services is List) {
      for (final s in services.whereType<Map>()) {
        final type = s['service_type']?.toString();
        final price = (s['price_cents'] as num?)?.toInt();
        final dur = (s['duration_minutes'] as num?)?.toInt();
        final cap = (s['capacity'] as num?)?.toInt();
        if (type == 'private') {
          if (price != null) privatePriceCents = price.clamp(1000, 50000);
          if (dur != null) durationMinutes = dur.clamp(15, 240);
        } else if (type == 'group') {
          if (price != null) groupPriceCents = price.clamp(1000, 50000);
          if (cap != null) groupCapacity = cap.clamp(2, 40);
        }
      }
    }
    final blocks = bundle['weekly_availability'];
    if (blocks is List && blocks.isNotEmpty) {
      final next = <Map<String, dynamic>>[];
      for (final b in blocks.whereType<Map>()) {
        final dow = (b['day_of_week'] as num?)?.toInt();
        final start = b['start']?.toString();
        final end = b['end']?.toString();
        if (dow != null && start != null && end != null) {
          next.add({'dayOfWeek': dow, 'startTime': start, 'endTime': end});
        }
      }
      if (next.isNotEmpty) availability = next;
    }
    final policies = bundle['policies'];
    if (policies is Map) {
      final c = policies['cancellation']?.toString();
      final w = policies['what_to_bring']?.toString();
      if (c != null && c.trim().isNotEmpty) cancellationPolicy = c.trim();
      if (w != null && w.trim().isNotEmpty) whatToBring = w.trim();
    }
  }

  // ── Summary edits (coach disposes) ──────────────────────────────────────────
  void setPrivatePrice(int cents) {
    privatePriceCents = cents.clamp(1000, 50000);
    notifyListeners();
  }

  void setGroupPrice(int cents) {
    groupPriceCents = cents.clamp(1000, 50000);
    notifyListeners();
  }

  void setDuration(int minutes) {
    durationMinutes = minutes.clamp(15, 240);
    notifyListeners();
  }

  void setOffers({bool? private, bool? group}) {
    if (private != null) offersPrivate = private;
    if (group != null) offersGroup = group;
    if (!offersPrivate && !offersGroup) offersPrivate = true; // never zero
    notifyListeners();
  }

  void setCancellationPolicy(String v) {
    cancellationPolicy = v;
    notifyListeners();
  }

  void setWhatToBring(String v) {
    whatToBring = v;
    notifyListeners();
  }

  void setAvailabilityChoice(String choice) {
    switch (choice) {
      case 'weekday':
        availability = _template.weekdayEvenings.map((b) => b.toBlock()).toList();
        break;
      case 'weekend':
        availability = _template.weekendMornings.map((b) => b.toBlock()).toList();
        break;
      case 'both':
        availability = [
          ..._template.weekdayEvenings.map((b) => b.toBlock()),
          ..._template.weekendMornings.map((b) => b.toBlock()),
        ];
        break;
    }
    notifyListeners();
  }

  /// A human-readable summary of the shared weekly grid for the summary card.
  String availabilityLabel() {
    if (availability.isEmpty) return 'No days set';
    const dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final days = availability
        .map((b) => (b['dayOfWeek'] as num?)?.toInt())
        .whereType<int>()
        .where((d) => d >= 0 && d <= 6)
        .map((d) => dow[d])
        .toSet()
        .toList();
    return days.join(', ');
  }

  // ── Proposed service bundle (also what confirm writes) ──────────────────────
  List<Map<String, dynamic>> proposedServices() {
    final out = <Map<String, dynamic>>[];
    if (offersPrivate) {
      out.add({
        'serviceType': 'private',
        'title': (_template.privateTemplate ?? _template.services.first)
            .titleFor(sport),
        'sport': sport,
        'durationMinutes': durationMinutes,
        'priceCents': privatePriceCents,
        'capacity': 1,
      });
    }
    if (offersGroup) {
      out.add({
        'serviceType': 'group',
        'title':
            (_template.groupTemplate ?? _template.services.last).titleFor(sport),
        'sport': sport,
        'durationMinutes': durationMinutes,
        'priceCents': groupPriceCents,
        'capacity': groupCapacity,
      });
    }
    return out;
  }

  // ── Confirm → EXISTING item-#1 repo methods ONLY ────────────────────────────
  Future<bool> confirm() async {
    if (_submitting) return false;
    final services = proposedServices();
    if (services.isEmpty) {
      error = 'Add at least one service before confirming.';
      notifyListeners();
      return false;
    }
    _submitting = true;
    error = null;
    notifyListeners();
    try {
      // 1) Optional saved venue (existing LocationRepository.createLocation).
      String? locationId;
      if (locationName.trim().isNotEmpty) {
        locationId = await _repo.createLocation({'name': locationName.trim()});
        if (locationId == null) {
          error = 'Could not save your location. Please try again.';
          return false;
        }
      }

      // 2) The ONE shared weekly grid — NOT a per-service calendar
      //    (existing ProviderAvailabilityRepository.setWeeklyAvailability).
      final okAvail = await _repo.setWeeklyAvailability(availability);
      if (!okAvail) {
        error = 'Could not save your availability. Please try again.';
        return false;
      }

      // 3) Each service (existing ServiceRepository.createService — NO times).
      for (final svc in services) {
        final payload = Map<String, dynamic>.from(svc);
        if (locationId != null) payload['locationId'] = locationId;
        final id = await _repo.createService(payload);
        if (id == null) {
          error =
              'Your availability was saved, but a service could not be created. '
              'Please try again.';
          return false;
        }
      }

      // 4) Policies the AI reply robot may cite
      //    (existing ProfileRepository.saveCoachPolicies).
      final okPolicies = await _repo.saveCoachPolicies({
        'cancellationPolicy': cancellationPolicy.trim(),
        'whatToBring': whatToBring.trim(),
      });
      if (!okPolicies) {
        error = 'Your services are live, but your policies could not be saved. '
            'You can add them from your profile.';
        // Services + availability succeeded; treat as a real, surfaced partial
        // failure (L-015) — do NOT report full success.
        return false;
      }

      _done = true;
      return true;
    } catch (e) {
      debugPrint('SetupInterviewController.confirm failed: $e');
      error = 'Something went wrong finishing setup. Please try again.';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ── Internals ────────────────────────────────────────────────────────────
  void _record(String q, String a) => _transcript.add({'q': q, 'a': a});

  void _advance(String userText) {
    _messages.add(SetupMessage(true, userText));
    _step += 1;
    _messages.add(SetupMessage(false, _promptFor(_step)));
    notifyListeners();
  }

  String _promptFor(int step) {
    switch (step) {
      case 1:
        return 'Great. Do you train athletes 1-on-1, in small groups, or both?';
      case 2:
        return 'How long is a typical session?';
      case 3:
        final hint = _template.privatePriceHint();
        return hint.isEmpty
            ? 'What do you charge per private session?'
            : 'What do you charge per private session? ($hint — you can start there.)';
      case 4:
        return 'When are you generally available? This is one shared calendar — '
            'every service uses it, and you can fine-tune it later.';
      case 5:
        return 'Where do you train? (You can skip this and add it later.)';
      case 6:
        return "What's your cancellation policy?";
      case 7:
        return 'Last one — anything athletes should bring?';
      default:
        return "Here's your setup summary — edit anything, then confirm.";
    }
  }

  static String _dollars(int cents) {
    final d = cents / 100;
    return d == d.roundToDouble()
        ? '\$${d.round()}'
        : '\$${d.toStringAsFixed(2)}';
  }

  String dollars(int cents) => _dollars(cents);
}
