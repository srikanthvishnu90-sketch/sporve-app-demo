import 'package:flutter/foundation.dart';

/// Provider Model Rebuild — item #4: SPORT TEMPLATES (data, NOT AI).
///
/// Per-sport, real-world defaults the setup interview turns into concrete
/// SUGGESTIONS a coach edits — never silent auto-creation. "Most basketball
/// trainers do 60-min privates at $70–90 — start with that?" is a template
/// default; the coach confirms or changes it.
///
/// GROUNDING (L-012 / L-016): a template value is a TYPICAL default for the
/// sport, never a fact about a SPECIFIC coach. The interview presents it as a
/// suggestion ("typical"), the coach disposes. Nothing here is ever quoted as
/// something THIS coach said or offers until they confirm it.
///
/// Pure data + resolution. No AI, no network, no new dependency. The controller
/// ([SetupInterviewController]) reads these to pre-fill the interview so a coach
/// reaches a first service in minimal taps (under-10-min budget).

/// A typical service offering for a sport (private or group). Prices are integer
/// CENTS, matching `services.price` (20260626 / 20260729_000100). Duration is a
/// suggestion; capacity is 1 for private, the sport's usual small-group size for
/// group.
@immutable
class ServiceTemplate {
  const ServiceTemplate({
    required this.serviceType, // 'private' | 'group'
    required this.durationMinutes,
    required this.priceLowCents,
    required this.priceHighCents,
    required this.capacity,
  });

  final String serviceType;
  final int durationMinutes;
  final int priceLowCents;
  final int priceHighCents;
  final int capacity;

  /// The default the interview pre-fills — the range midpoint rounded to the
  /// nearest $5 so the suggestion reads like a real price ("$80", not "$81.37").
  int get priceMidCents {
    final mid = (priceLowCents + priceHighCents) / 2;
    return (mid / 500).round() * 500;
  }

  /// A generic, grounded title descriptor — carries the coach's own sport, never
  /// a fabricated claim ("elite", "certified", etc.). The coach edits it freely.
  String titleFor(String sport) => serviceType == 'group'
      ? '$sport small-group session'
      : '$sport private lesson';
}

/// One block of a coach's typical WEEKLY availability. day_of_week 0=Sun..6=Sat,
/// times "HH:mm" — the shape [setWeeklyAvailability] expects. These feed the ONE
/// shared weekly grid (never a per-service calendar).
@immutable
class AvailabilityTemplate {
  const AvailabilityTemplate(this.dayOfWeek, this.start, this.end);
  final int dayOfWeek;
  final String start;
  final String end;

  Map<String, dynamic> toBlock() =>
      {'dayOfWeek': dayOfWeek, 'startTime': start, 'endTime': end};
}

/// The full default bundle for a sport: what a typical coach sells, when they
/// typically train, and sensible starter policies. All SUGGESTIONS.
@immutable
class SportTemplate {
  const SportTemplate({
    required this.sport,
    required this.services,
    required this.weekdayEvenings,
    required this.weekendMornings,
    required this.cancellationPolicy,
    required this.whatToBring,
  });

  final String sport;
  final List<ServiceTemplate> services;
  final List<AvailabilityTemplate> weekdayEvenings;
  final List<AvailabilityTemplate> weekendMornings;
  final String cancellationPolicy;
  final String whatToBring;

  ServiceTemplate? get privateTemplate => _firstOfType('private');
  ServiceTemplate? get groupTemplate => _firstOfType('group');

  ServiceTemplate? _firstOfType(String type) {
    for (final s in services) {
      if (s.serviceType == type) return s;
    }
    return null;
  }

  /// "60-min privates typically run $70–90" — the sentence the interview shows
  /// so the coach sees the template is a suggestion, not a demand.
  String privatePriceHint() {
    final t = privateTemplate;
    if (t == null) return '';
    return '${t.durationMinutes}-min privates typically run '
        '${_dollars(t.priceLowCents)}–${_dollars(t.priceHighCents)}';
  }
}

String _dollars(int cents) {
  final d = cents / 100;
  return d == d.roundToDouble() ? '\$${d.round()}' : '\$${d.toStringAsFixed(2)}';
}

/// Registry of per-sport templates + resolution. Case-insensitive; an unknown
/// sport falls back to a grounded GENERIC template (never nothing — the coach
/// still gets sensible, editable suggestions).
class SportTemplates {
  SportTemplates._();

  /// Shared "typical youth-training" cadence — evenings on weekdays, mornings on
  /// weekends. Sports rarely differ here, so one default keeps suggestions honest
  /// and simple. The coach reshapes the grid in one place (item #1 promise).
  static const List<AvailabilityTemplate> _weekdayEvenings = [
    AvailabilityTemplate(2, '17:00', '20:00'), // Tue
    AvailabilityTemplate(4, '17:00', '20:00'), // Thu
  ];
  static const List<AvailabilityTemplate> _weekendMornings = [
    AvailabilityTemplate(6, '09:00', '12:00'), // Sat
  ];

  static const String _defaultCancellation =
      '24-hour cancellation — cancel at least a day ahead for a full credit.';

  static SportTemplate _sport({
    required String sport,
    required int privateDuration,
    required int privateLow,
    required int privateHigh,
    required int groupPrice,
    required int groupCapacity,
    required String whatToBring,
    int? groupDuration,
  }) {
    return SportTemplate(
      sport: sport,
      services: [
        ServiceTemplate(
          serviceType: 'private',
          durationMinutes: privateDuration,
          priceLowCents: privateLow,
          priceHighCents: privateHigh,
          capacity: 1,
        ),
        ServiceTemplate(
          serviceType: 'group',
          durationMinutes: groupDuration ?? privateDuration,
          priceLowCents: (groupPrice * 0.85).round(),
          priceHighCents: (groupPrice * 1.15).round(),
          capacity: groupCapacity,
        ),
      ],
      weekdayEvenings: _weekdayEvenings,
      weekendMornings: _weekendMornings,
      cancellationPolicy: _defaultCancellation,
      whatToBring: whatToBring,
    );
  }

  /// Keyed by lowercased sport name. Curated across the marketplace's core sports;
  /// anything else resolves to [_generic].
  static final Map<String, SportTemplate> _bySport = {
    'basketball': _sport(
      sport: 'Basketball',
      privateDuration: 60,
      privateLow: 7000,
      privateHigh: 9000,
      groupPrice: 4000,
      groupCapacity: 6,
      whatToBring: 'Basketball shoes, water, and a ball if you have one.',
    ),
    'soccer': _sport(
      sport: 'Soccer',
      privateDuration: 60,
      privateLow: 6000,
      privateHigh: 8000,
      groupPrice: 3000,
      groupCapacity: 8,
      whatToBring: 'Cleats, shin guards, water, and a size-appropriate ball.',
    ),
    'tennis': _sport(
      sport: 'Tennis',
      privateDuration: 60,
      privateLow: 7000,
      privateHigh: 10000,
      groupPrice: 4000,
      groupCapacity: 4,
      whatToBring: 'Racquet, court shoes, and water.',
    ),
    'baseball': _sport(
      sport: 'Baseball',
      privateDuration: 60,
      privateLow: 6000,
      privateHigh: 8500,
      groupPrice: 3500,
      groupCapacity: 8,
      whatToBring: 'Glove, bat, cleats, and water.',
    ),
    'softball': _sport(
      sport: 'Softball',
      privateDuration: 60,
      privateLow: 6000,
      privateHigh: 8500,
      groupPrice: 3500,
      groupCapacity: 8,
      whatToBring: 'Glove, bat, cleats, and water.',
    ),
    'volleyball': _sport(
      sport: 'Volleyball',
      privateDuration: 60,
      privateLow: 6000,
      privateHigh: 8000,
      groupPrice: 3000,
      groupCapacity: 8,
      whatToBring: 'Court shoes, knee pads, and water.',
    ),
    'football': _sport(
      sport: 'Football',
      privateDuration: 60,
      privateLow: 6000,
      privateHigh: 9000,
      groupPrice: 3500,
      groupCapacity: 10,
      whatToBring: 'Cleats, gloves if you use them, and water.',
    ),
    'swimming': _sport(
      sport: 'Swimming',
      privateDuration: 30,
      privateLow: 5000,
      privateHigh: 7000,
      groupPrice: 2500,
      groupCapacity: 6,
      groupDuration: 45,
      whatToBring: 'Swimsuit, goggles, towel, and a cap if you use one.',
    ),
    'golf': _sport(
      sport: 'Golf',
      privateDuration: 60,
      privateLow: 7500,
      privateHigh: 12000,
      groupPrice: 4500,
      groupCapacity: 4,
      whatToBring: 'Your clubs if you have them, a glove, and water.',
    ),
    'gymnastics': _sport(
      sport: 'Gymnastics',
      privateDuration: 60,
      privateLow: 6000,
      privateHigh: 8000,
      groupPrice: 3000,
      groupCapacity: 6,
      whatToBring: 'Fitted athletic wear, hair tie, water. No jewelry.',
    ),
    'wrestling': _sport(
      sport: 'Wrestling',
      privateDuration: 60,
      privateLow: 6000,
      privateHigh: 8500,
      groupPrice: 3500,
      groupCapacity: 8,
      whatToBring: 'Wrestling shoes, athletic wear, and water.',
    ),
    'hockey': _sport(
      sport: 'Hockey',
      privateDuration: 60,
      privateLow: 7000,
      privateHigh: 10000,
      groupPrice: 4500,
      groupCapacity: 8,
      whatToBring: 'Full gear, stick, and water.',
    ),
  };

  /// Grounded fallback for a sport we don't have a curated template for. Still a
  /// real, editable starting point — never an empty form.
  static final SportTemplate _generic = _sport(
    sport: 'General',
    privateDuration: 60,
    privateLow: 6000,
    privateHigh: 8000,
    groupPrice: 3000,
    groupCapacity: 6,
    whatToBring: 'Appropriate athletic wear, footwear, and water.',
  );

  /// Resolve a template for [sport] (case-insensitive, trimmed). Never null.
  /// [preserveSportName]: the returned template carries the coach's own sport
  /// string when it's a real sport we just don't have curated pricing for, so the
  /// suggestions read in their words.
  static SportTemplate forSport(String? sport) {
    final key = (sport ?? '').trim().toLowerCase();
    final hit = _bySport[key];
    if (hit != null) return hit;
    // Unknown sport: use generic pricing but keep the coach's own sport label so
    // service titles/summaries stay in their words (grounded), not "General".
    final label = (sport ?? '').trim();
    if (label.isEmpty) return _generic;
    return SportTemplate(
      sport: label,
      services: _generic.services,
      weekdayEvenings: _generic.weekdayEvenings,
      weekendMornings: _generic.weekendMornings,
      cancellationPolicy: _generic.cancellationPolicy,
      whatToBring: _generic.whatToBring,
    );
  }

  /// The sports we have curated templates for (title-cased), for chip suggestions.
  static List<String> get knownSports =>
      _bySport.values.map((t) => t.sport).toList();
}
