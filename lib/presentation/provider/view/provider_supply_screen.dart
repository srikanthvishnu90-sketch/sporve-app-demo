import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../controllers/supply_controller.dart';
import '../../widgets/common_widgets.dart';

/// Provider Model Rebuild — Part 0 / item #1. The single provider surface that
/// replaces per-listing calendars: define a SERVICE (no times), set the ONE
/// weekly AVAILABILITY grid (+ buffer + vacation), and manage saved LOCATIONS.
/// No new nav tab — reached from the provider area. Because a service carries no
/// times, editing Tuesday here updates EVERY service; a second service never
/// re-asks for times.
class ProviderSupplyScreen extends StatefulWidget {
  const ProviderSupplyScreen({super.key});

  @override
  State<ProviderSupplyScreen> createState() => _ProviderSupplyScreenState();
}

class _ProviderSupplyScreenState extends State<ProviderSupplyScreen> {
  int _section = 0; // 0 services · 1 availability · 2 locations

  static const _dayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _serviceTypes = {
    'private': 'Private',
    'group': 'Group',
    'camp': 'Camp',
    'team_block': 'Team block',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplyController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SupplyController>();
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  SporveIconButton(
                    Icons.arrow_back,
                    circle: true,
                    iconSize: 20,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your offerings',
                          style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ONE WEEKLY CALENDAR · EVERY SERVICE',
                          style: AppTypography.font(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _segmented(),
            const SizedBox(height: 8),
            Expanded(child: _body(c)),
          ],
        ),
      ),
    );
  }

  Widget _segmented() {
    const labels = ['Services', 'Availability', 'Locations'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _section = i),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _section == i ? AppColors.slate : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    child: Text(
                      labels[i],
                      style: AppTypography.font(
                        color: _section == i
                            ? AppColors.onSlate
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(SupplyController c) {
    if (c.loading && c.services.isEmpty && c.availability.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.slateText,
          strokeWidth: 2,
        ),
      );
    }
    if (c.error) {
      return ErrorRetry(
        message: "We couldn't load your offerings. Please try again.",
        onRetry: () => c.load(),
      );
    }
    switch (_section) {
      case 1:
        return _availabilityBody(c);
      case 2:
        return _locationsBody(c);
      default:
        return _servicesBody(c);
    }
  }

  // ── Section 1: Services ─────────────────────────────────────────────────────
  Widget _servicesBody(SupplyController c) {
    return Column(
      children: [
        Expanded(
          child: c.services.isEmpty
              ? _empty(
                  Icons.sell_outlined,
                  'No services yet.\nAdd what you sell — e.g. "60-min private, \$80". '
                  'You set the times once, in Availability.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  itemCount: c.services.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _serviceCard(c, c.services[i]),
                ),
        ),
        _addBar(
          c.saving ? 'Saving…' : '+ Add a service',
          onTap: c.saving ? null : () => _openAddServiceSheet(c),
        ),
      ],
    );
  }

  Widget _serviceCard(SupplyController c, Map<String, dynamic> s) {
    final id = s['_id']?.toString() ?? '';
    final active = (s['active'] ?? true) == true;
    final type = _serviceTypes[s['serviceType']] ?? 'Private';
    final cap = (s['capacity'] ?? 1) as int;
    final sub =
        '$type · ${s['durationMinutes'] ?? 0} min · ${_fmtPrice(s['priceCents'])}'
        '${cap > 1 ? ' · up to $cap' : ''}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (s['title'] ?? 'Untitled').toString(),
                      style: AppTypography.font(
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(active),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Preview slots',
                  onTap: () => _previewSlots(c, s),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  label: active ? 'Pause' : 'Resume',
                  onTap: () async {
                    final ok = await c.setServiceActive(id, !active);
                    _toast(ok
                        ? (active
                            ? 'Paused — it stays saved, just hidden.'
                            : 'Resumed.')
                        : 'Could not update. Try again.');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _previewSlots(
      SupplyController c, Map<String, dynamic> s) async {
    if (c.availability.isEmpty) {
      _toast('Set your weekly availability first — services read from it.');
      return;
    }
    final slots = await c.previewSlots(s['_id'].toString());
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next 2 weeks · ${(s['title'] ?? '').toString()}',
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Generated from your ONE weekly grid — edit Tuesday once and every '
              'service updates.',
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (slots.isEmpty)
              Text(
                'No bookable slots in the window (check availability, vacation, or '
                'skipped days).',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: slots.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.hairline, height: 16),
                  itemBuilder: (_, i) {
                    final slot = slots[i];
                    final seats = slot['seatsRemaining'];
                    final isGroup = s['serviceType'] == 'group' ||
                        ((s['capacity'] ?? 1) as int) > 1;
                    final row = Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_fmtDate(slot['date'].toString())} · '
                          '${_fmtTime(slot['startTime']?.toString())}',
                          style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$seats seat${seats == 1 ? '' : 's'} left',
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                            // Group services: tap a slot to see who's on it
                            // (first name + age band only — L-005).
                            if (isGroup) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.groups_outlined,
                                  size: 16, color: AppColors.textTertiary),
                            ],
                          ],
                        ),
                      ],
                    );
                    if (!isGroup) return row;
                    return InkWell(
                      onTap: () => _showGroupRoster(c, s, slot),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: row,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // The coach's group mini-roster for one slot — first name + age band ONLY
  // (L-005). Reads via the same canonical slot identity the family's claim used
  // (slot['startTime'] is the bookable_slots start_time string). Honest empty
  // state; a failed read shows the empty message, never a fake roster (L-015).
  Future<void> _showGroupRoster(
    SupplyController c,
    Map<String, dynamic> s,
    Map<String, dynamic> slot,
  ) async {
    final roster = await c.groupRoster(
      serviceId: s['_id'].toString(),
      slotDate: slot['date'].toString(),
      slotTime: slot['startTime']?.toString() ?? '',
    );
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text(
          '${_fmtDate(slot['date'].toString())} · '
          '${_fmtTime(slot['startTime']?.toString())}',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: roster.isEmpty
            ? Text(
                'No one has claimed a seat yet.',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in roster)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${(r['athleteFirstName'] ?? 'Athlete').toString()}'
                        '${r['athleteAgeBand'] != null ? ' · ${r['athleteAgeBand']}' : ''}',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: AppTypography.font(color: AppColors.slateText),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddServiceSheet(SupplyController c) async {
    String type = 'private';
    final titleCtrl = TextEditingController();
    final sportCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '80');
    int duration = 60;
    int capacity = 1;
    String? locationId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New service',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What you sell — no times here. Times come from your one '
                      'weekly availability.',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Type'),
                    const SizedBox(height: 6),
                    _chips(
                      _serviceTypes.entries
                          .map((e) => MapEntry(e.key, e.value))
                          .toList(),
                      type,
                      (v) => setSheet(() {
                        type = v;
                        if (v == 'private') capacity = 1;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Title'),
                    const SizedBox(height: 6),
                    _textField(titleCtrl, 'e.g. 60-min private lesson'),
                    const SizedBox(height: 16),
                    _fieldLabel('Sport'),
                    const SizedBox(height: 6),
                    _textField(sportCtrl, 'e.g. Basketball'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Duration'),
                              const SizedBox(height: 6),
                              _numChips(
                                const [30, 45, 60, 90],
                                duration,
                                (v) => setSheet(() => duration = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Price per session'),
                    const SizedBox(height: 6),
                    _priceField(priceCtrl),
                    if (type != 'private') ...[
                      const SizedBox(height: 16),
                      _fieldLabel('Capacity'),
                      const SizedBox(height: 6),
                      _numChips(
                        const [2, 4, 6, 8, 12],
                        capacity < 2 ? 2 : capacity,
                        (v) => setSheet(() => capacity = v),
                      ),
                    ],
                    if (c.locations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _fieldLabel('Location (optional)'),
                      const SizedBox(height: 6),
                      _chips(
                        [
                          const MapEntry<String?, String>(null, 'None'),
                          ...c.locations.map((l) => MapEntry<String?, String>(
                              l['_id'].toString(), (l['name'] ?? '').toString())),
                        ],
                        locationId,
                        (v) => setSheet(() => locationId = v),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _primaryBtn('Add service', () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        _toast('Give the service a title.');
                        return;
                      }
                      final dollars =
                          double.tryParse(priceCtrl.text.trim()) ?? 0;
                      final ok = await c.addService(
                        serviceType: type,
                        title: titleCtrl.text.trim(),
                        sport: sportCtrl.text.trim().isEmpty
                            ? null
                            : sportCtrl.text.trim(),
                        durationMinutes: duration,
                        priceCents: (dollars * 100).round(),
                        capacity: type == 'private' ? 1 : capacity,
                        locationId: locationId,
                      );
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      _toast(ok
                          ? 'Service added — it uses your weekly availability.'
                          : 'Could not save. Try again.');
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    titleCtrl.dispose();
    sportCtrl.dispose();
    priceCtrl.dispose();
  }

  // ── Section 2: Weekly availability ──────────────────────────────────────────
  Widget _availabilityBody(SupplyController c) {
    // Local editable copy of the grid, keyed by day.
    final byDay = <int, List<Map<String, String>>>{};
    for (final b in c.availability) {
      final d = (b['dayOfWeek'] as num?)?.toInt() ?? 0;
      byDay.putIfAbsent(d, () => []).add({
        'start': _hm(b['startTime']?.toString()),
        'end': _hm(b['endTime']?.toString()),
      });
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _settingsCard(c),
        const SizedBox(height: 16),
        Text(
          'WEEKLY HOURS',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'One grid, shared by every service. Edit a day once and it applies '
          'everywhere.',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        for (var d = 0; d < 7; d++) _dayRow(c, d, byDay[d] ?? const []),
      ],
    );
  }

  Widget _dayRow(SupplyController c, int day, List<Map<String, String>> blocks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dayShort[day],
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => _addBlock(c, day),
                child: Text(
                  '+ Add hours',
                  style: AppTypography.font(
                    color: AppColors.slateText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Unavailable',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            )
          else
            for (var i = 0; i < blocks.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_fmtTime(blocks[i]['start'])} – ${_fmtTime(blocks[i]['end'])}',
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeBlock(c, day, i),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _addBlock(SupplyController c, int day) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 15, minute: 0),
      helpText: 'Start time',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 3) % 24, minute: start.minute),
      helpText: 'End time',
    );
    if (end == null) return;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) {
      _toast('End time must be after start time.');
      return;
    }
    final blocks = _currentBlocks(c);
    blocks.add({
      'dayOfWeek': day,
      'startTime': _hmFromTod(start),
      'endTime': _hmFromTod(end),
    });
    final ok = await c.saveWeeklyAvailability(blocks);
    _toast(ok
        ? 'Saved — every service now offers these hours.'
        : 'Could not save availability. Try again.');
  }

  Future<void> _removeBlock(
      SupplyController c, int day, int indexInDay) async {
    // Rebuild the full block list, dropping the nth block of that day.
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final b in c.availability) {
      final d = (b['dayOfWeek'] as num?)?.toInt() ?? 0;
      grouped.putIfAbsent(d, () => []).add(b);
    }
    if (grouped[day] != null && indexInDay < grouped[day]!.length) {
      grouped[day]!.removeAt(indexInDay);
    }
    final blocks = <Map<String, dynamic>>[];
    grouped.forEach((d, list) {
      for (final b in list) {
        blocks.add({
          'dayOfWeek': d,
          'startTime': _hm(b['startTime']?.toString()),
          'endTime': _hm(b['endTime']?.toString()),
        });
      }
    });
    final ok = await c.saveWeeklyAvailability(blocks);
    _toast(ok ? 'Hours removed.' : 'Could not save. Try again.');
  }

  List<Map<String, dynamic>> _currentBlocks(SupplyController c) {
    return c.availability
        .map((b) => {
              'dayOfWeek': (b['dayOfWeek'] as num?)?.toInt() ?? 0,
              'startTime': _hm(b['startTime']?.toString()),
              'endTime': _hm(b['endTime']?.toString()),
            })
        .toList();
  }

  Widget _settingsCard(SupplyController c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Buffer between sessions'),
          const SizedBox(height: 8),
          _numChips(const [0, 5, 10, 15, 30], c.bufferMinutes, (v) async {
            final ok = await c.setBuffer(v);
            if (!ok) _toast('Could not save buffer. Try again.');
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Vacation'),
                    const SizedBox(height: 4),
                    Text(
                      c.vacationUntil == null
                          ? 'Not on vacation — bookable as normal.'
                          : 'Away until ${_fmtDate(c.vacationUntil!)}',
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _actionBtn(
                label: c.vacationUntil == null ? 'Set' : 'Clear',
                onTap: () async {
                  if (c.vacationUntil != null) {
                    final ok = await c.setVacationUntil(null);
                    _toast(ok ? 'Vacation cleared.' : 'Could not update.');
                    return;
                  }
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    helpText: 'Away until',
                  );
                  if (picked == null) return;
                  final ok = await c.setVacationUntil(_iso(picked));
                  _toast(ok
                      ? 'Vacation set — slots hidden through that date.'
                      : 'Could not update. Try again.');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section 3: Locations ────────────────────────────────────────────────────
  Widget _locationsBody(SupplyController c) {
    return Column(
      children: [
        Expanded(
          child: c.locations.isEmpty
              ? _empty(
                  Icons.place_outlined,
                  'No saved venues yet.\nAdd a court, field, or gym and pin it to '
                  'a service.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  itemCount: c.locations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _locationCard(c, c.locations[i]),
                ),
        ),
        _addBar(
          c.saving ? 'Saving…' : '+ Add a location',
          onTap: c.saving ? null : () => _openAddLocationSheet(c),
        ),
      ],
    );
  }

  Widget _locationCard(SupplyController c, Map<String, dynamic> l) {
    final id = l['_id']?.toString() ?? '';
    final addr = [l['addressLine1'], l['city'], l['state'], l['zip']]
        .where((x) => x != null && x.toString().trim().isNotEmpty)
        .join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (l['name'] ?? '').toString(),
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (addr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    addr,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final ok = await c.deleteLocation(id);
              _toast(ok
                  ? 'Venue removed — services that used it were un-pinned.'
                  : 'Could not remove. Try again.');
            },
            child: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddLocationSheet(SupplyController c) async {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final zipCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New location',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _fieldLabel('Name'),
                const SizedBox(height: 6),
                _textField(nameCtrl, 'e.g. Downtown Rec Center'),
                const SizedBox(height: 16),
                _fieldLabel('Address'),
                const SizedBox(height: 6),
                _textField(addrCtrl, 'Street'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _textField(cityCtrl, 'City')),
                    const SizedBox(width: 10),
                    SizedBox(width: 70, child: _textField(stateCtrl, 'State')),
                    const SizedBox(width: 10),
                    SizedBox(width: 90, child: _textField(zipCtrl, 'ZIP')),
                  ],
                ),
                const SizedBox(height: 22),
                _primaryBtn('Add location', () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    _toast('Give the location a name.');
                    return;
                  }
                  final ok = await c.addLocation(
                    name: nameCtrl.text.trim(),
                    addressLine1: addrCtrl.text.trim(),
                    city: cityCtrl.text.trim(),
                    state: stateCtrl.text.trim(),
                    zip: zipCtrl.text.trim(),
                  );
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  _toast(ok ? 'Location saved.' : 'Could not save. Try again.');
                }),
              ],
            ),
          ),
        );
      },
    );
    nameCtrl.dispose();
    addrCtrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    zipCtrl.dispose();
  }

  // ── Shared small widgets ────────────────────────────────────────────────────
  Widget _empty(IconData icon, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.textTertiary, size: 44),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _addBar(String label, {VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          onTap: onTap,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.slate,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Text(
              label,
              style: AppTypography.font(
                color: AppColors.onSlate,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

  Widget _primaryBtn(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.slate,
            foregroundColor: AppColors.onSlate,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
          ),
          onPressed: onTap,
          child: Text(
            label,
            style: AppTypography.font(
              color: AppColors.onSlate,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Widget _actionBtn({required String label, required VoidCallback onTap}) =>
      InkWell(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.hairlineStrong),
          ),
          child: Text(
            label,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Widget _chips<T>(
    List<MapEntry<T, String>> options,
    T selected,
    ValueChanged<T> onSelect,
  ) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onSelect(o.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected == o.key
                      ? AppColors.slateTint
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  border: Border.all(
                    color: selected == o.key
                        ? AppColors.slateBorder
                        : AppColors.hairlineStrong,
                  ),
                ),
                child: Text(
                  o.value,
                  style: AppTypography.font(
                    color: selected == o.key
                        ? AppColors.slateText
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _numChips(List<int> options, int selected, ValueChanged<int> onSelect) =>
      _chips(
        options
            .map((o) => MapEntry(o, o == 0 ? 'None' : '$o'))
            .toList(),
        selected,
        onSelect,
      );

  Widget _textField(TextEditingController ctrl, String hint) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairlineStrong),
        ),
        child: Center(
          child: TextField(
            controller: ctrl,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hint,
              hintStyle: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );

  Widget _priceField(TextEditingController ctrl) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairlineStrong),
        ),
        child: Row(
          children: [
            Text(
              '\$',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: '80',
                ),
              ),
            ),
          ],
        ),
      );

  Widget _fieldLabel(String text) => Text(
        text.toUpperCase(),
        style: AppTypography.font(
          color: AppColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      );

  Widget _statusPill(bool active) {
    final color = active ? AppColors.slateText : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        active ? 'ACTIVE' : 'PAUSED',
        style: AppTypography.font(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── Formatting helpers ──────────────────────────────────────────────────────
  String _hm(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  String _hmFromTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    var hh = h % 12;
    if (hh == 0) hh = 12;
    return '$hh:${m.toString().padLeft(2, '0')} $period';
  }

  String _fmtPrice(dynamic cents) {
    final c = (cents as num?)?.toInt() ?? 0;
    final dollars = c / 100.0;
    return dollars == dollars.roundToDouble()
        ? '\$${dollars.toStringAsFixed(0)}'
        : '\$${dollars.toStringAsFixed(2)}';
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const mon = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${mon[d.month - 1]} ${d.day}';
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _toast(String msg) {
    Get.snackbar(
      'Offerings',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }
}
