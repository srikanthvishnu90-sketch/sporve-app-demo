import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../controllers/recurring_slots_controller.dart';
import '../../widgets/common_widgets.dart';

/// Coach OS — RECURRING WEEKLY SLOTS (AI Front Office #1). A coach adds a standing
/// weekly slot once ("Tuesdays 5pm, 60 min, $80") and it shows up every week.
/// Skipping one week records an exception WITHOUT deleting the slot. This is the
/// SUPPLY side of the season and complements the family's standing claim
/// (recurring_bookings). No money moves here — a slot carries a price QUOTE only.
class ProviderRecurringSlotsScreen extends StatefulWidget {
  const ProviderRecurringSlotsScreen({super.key});

  @override
  State<ProviderRecurringSlotsScreen> createState() =>
      _ProviderRecurringSlotsScreenState();
}

class _ProviderRecurringSlotsScreenState
    extends State<ProviderRecurringSlotsScreen> {
  static const _days = [
    'Sundays',
    'Mondays',
    'Tuesdays',
    'Wednesdays',
    'Thursdays',
    'Fridays',
    'Saturdays',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecurringSlotsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RecurringSlotsController>();
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SporveIconButton(
                    Icons.arrow_back,
                    circle: true,
                    iconSize: 20,
                    onTap: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Weekly slots',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'YOUR STANDING WEEKLY AVAILABILITY',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: _body(c)),
            _addBar(c),
          ],
        ),
      ),
    );
  }

  Widget _body(RecurringSlotsController c) {
    if (c.loading && c.slots.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.slateText,
          strokeWidth: 2,
        ),
      );
    }
    if (c.error) {
      return ErrorRetry(
        message: "We couldn't load your weekly slots. Please try again.",
        onRetry: () => c.load(),
      );
    }
    if (c.slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_repeat_outlined,
                color: AppColors.textTertiary,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                'No weekly slots yet.\nAdd one — like "Tuesdays 5pm, 60 min, \$80" — '
                'and it will show up every week.',
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
    }
    return RefreshIndicator(
      color: AppColors.slateText,
      onRefresh: () => c.load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        itemCount: c.slots.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _slotCard(c, c.slots[i]),
      ),
    );
  }

  Widget _slotCard(RecurringSlotsController c, Map<String, dynamic> s) {
    final id = s['_id']?.toString() ?? '';
    final dow = (s['dayOfWeek'] as int?) ?? 0;
    final active = (s['active'] ?? true) == true;
    final skips = c.exceptionsFor(id);
    final title =
        '${_days[dow.clamp(0, 6)]} · ${_fmtTime(s['startTime']?.toString())}';
    final sub =
        '${s['durationMinutes'] ?? 0} min · ${_fmtPrice(s['priceCents'])}'
        '${((s['capacity'] ?? 1) as int) > 1 ? ' · up to ${s['capacity']} athletes' : ''}';

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
                      title,
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
          if (skips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Skipped: ${skips.map(_fmtDate).join(', ')}',
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Skip a week',
                  filled: false,
                  onTap: () => _pickSkipWeek(c, id),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  label: active ? 'Pause' : 'Resume',
                  filled: false,
                  onTap: () async {
                    final ok = await c.setActive(id, !active);
                    _toast(ok
                        ? (active
                            ? 'Slot paused — it stays saved, just hidden.'
                            : 'Slot resumed.')
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

  Widget _addBar(RecurringSlotsController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        onTap: c.saving ? null : () => _openAddSheet(c),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.slate,
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          child: Text(
            c.saving ? 'Saving…' : '+ Add weekly slot',
            style: AppTypography.font(
              color: AppColors.onSlate,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ── Add-slot bottom sheet ───────────────────────────────────────────────────
  Future<void> _openAddSheet(RecurringSlotsController c) async {
    int day = 2; // Tuesday default
    TimeOfDay time = const TimeOfDay(hour: 17, minute: 0); // 5:00 PM
    int duration = 60;
    final priceCtrl = TextEditingController(text: '80');

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New weekly slot',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set it once — it repeats every week.',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _fieldLabel('Day'),
                  const SizedBox(height: 6),
                  _daySelector(day, (d) => setSheet(() => day = d)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Start time'),
                            const SizedBox(height: 6),
                            _pickerTile(
                              _fmtTod(time),
                              () async {
                                final picked = await showTimePicker(
                                  context: sheetCtx,
                                  initialTime: time,
                                );
                                if (picked != null) {
                                  setSheet(() => time = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Duration'),
                            const SizedBox(height: 6),
                            _durationSelector(
                              duration,
                              (d) => setSheet(() => duration = d),
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
                  const SizedBox(height: 22),
                  SizedBox(
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
                      onPressed: () async {
                        final dollars =
                            double.tryParse(priceCtrl.text.trim()) ?? 0;
                        final cents = (dollars * 100).round();
                        final start =
                            '${time.hour.toString().padLeft(2, '0')}:'
                            '${time.minute.toString().padLeft(2, '0')}';
                        final ok = await c.addSlot(
                          dayOfWeek: day,
                          startTime: start,
                          durationMinutes: duration,
                          priceCents: cents,
                        );
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        _toast(ok
                            ? 'Weekly slot added — it will show up every week.'
                            : 'Could not save the slot. Try again.');
                      },
                      child: Text(
                        'Add slot',
                        style: AppTypography.font(
                          color: AppColors.onSlate,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    priceCtrl.dispose();
  }

  Future<void> _pickSkipWeek(RecurringSlotsController c, String slotId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Skip which week?',
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    final ok = await c.skipWeek(slotId, iso);
    _toast(ok
        ? "That week is skipped — the slot stays for every other week."
        : 'Could not skip. Try again.');
  }

  // ── Small sheet widgets ─────────────────────────────────────────────────────
  Widget _daySelector(int selected, ValueChanged<int> onSelect) {
    const short = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: [
        for (var d = 0; d < 7; d++)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(d),
              child: Container(
                margin: EdgeInsets.only(right: d == 6 ? 0 : 6),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == d
                      ? AppColors.slateTint
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(
                    color: selected == d
                        ? AppColors.slateBorder
                        : AppColors.hairlineStrong,
                  ),
                ),
                child: Text(
                  short[d],
                  style: AppTypography.font(
                    color: selected == d
                        ? AppColors.slateText
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _durationSelector(int selected, ValueChanged<int> onSelect) {
    const options = [30, 45, 60, 90];
    return Row(
      children: [
        for (final o in options)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(o),
              child: Container(
                margin: EdgeInsets.only(right: o == options.last ? 0 : 6),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == o
                      ? AppColors.slateTint
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(
                    color: selected == o
                        ? AppColors.slateBorder
                        : AppColors.hairlineStrong,
                  ),
                ),
                child: Text(
                  '$o',
                  style: AppTypography.font(
                    color: selected == o
                        ? AppColors.slateText
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pickerTile(String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairlineStrong),
        ),
        child: Text(
          value,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _priceField(TextEditingController ctrl) {
    return Container(
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
  }

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

  Widget _actionBtn({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.slate : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: filled ? AppColors.slate : AppColors.hairlineStrong,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.font(
            color: filled ? AppColors.onSlate : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Formatting ──────────────────────────────────────────────────────────────
  // startTime comes back as "HH:mm" (mock) or "HH:mm:ss" (Postgres time).
  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return _fmtTod(TimeOfDay(hour: h, minute: m));
  }

  String _fmtTod(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    var h = t.hour % 12;
    if (h == 0) h = 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${mon[d.month - 1]} ${d.day}';
  }

  void _toast(String msg) {
    Get.snackbar(
      'Weekly slots',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }
}
