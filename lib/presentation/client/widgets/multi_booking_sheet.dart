import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/home_controller.dart';
import '../controllers/multi_booking_controller.dart';

/// Provider Model Rebuild — item #2 (family side, docs/PROVIDER-UI-FOLLOWUPS.md
/// #1): opens the three ways a family can claim a shared slot on a service —
/// a GROUP seat, a RECURRING weekly claim, or a prepaid PACK credit redemption.
/// Self-contained: reads [ServiceRepository.bookableSlots] +
/// [MultiBookingRepository] directly, never touches the legacy
/// `booking_flow_screen.dart` "program" model.
Future<void> showMultiBookingSheet(
  BuildContext context, {
  required String providerId,
  required String serviceId,
  required String serviceTitle,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ChangeNotifierProvider(
      create: (ctx) =>
          MultiBookingController(ctx.read<AppRepository>())
            ..load(providerId: providerId, serviceId: serviceId),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _MultiBookingSheet(
          providerId: providerId,
          serviceId: serviceId,
          serviceTitle: serviceTitle,
        ),
      ),
    ),
  );
}

class _MultiBookingSheet extends StatefulWidget {
  final String providerId;
  final String serviceId;
  final String serviceTitle;
  const _MultiBookingSheet({
    required this.providerId,
    required this.serviceId,
    required this.serviceTitle,
  });

  @override
  State<_MultiBookingSheet> createState() => _MultiBookingSheetState();
}

class _MultiBookingSheetState extends State<_MultiBookingSheet> {
  int _tab = 0; // 0 = group, 1 = recurring, 2 = pack

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.card),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More booking options',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.serviceTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SporveSegmented(
                    segments: const ['Group seat', 'Recurring', 'Pack credit'],
                    selected: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<MultiBookingController>(
                builder: (context, controller, _) {
                  if (controller.loading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.slateText,
                          ),
                        ),
                      ),
                    );
                  }
                  if (controller.error) {
                    return ErrorRetry(
                      onRetry: () => controller.load(
                        providerId: widget.providerId,
                        serviceId: widget.serviceId,
                      ),
                    );
                  }
                  switch (_tab) {
                    case 1:
                      return _RecurringTab(
                        serviceId: widget.serviceId,
                        scrollController: scrollController,
                      );
                    case 2:
                      return _PackTab(
                        serviceId: widget.serviceId,
                        controller: controller,
                        scrollController: scrollController,
                      );
                    default:
                      return _GroupTab(
                        serviceId: widget.serviceId,
                        controller: controller,
                        scrollController: scrollController,
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared bits ─────────────────────────────────────────────────────────────

/// Family's own athletes (from [HomeProvider]) — pick one to book for. Falls
/// back gracefully to a null/unnamed athlete when the family has none yet
/// (the demo/mock still accepts a booking; the empty state points at "Add a
/// child" rather than silently blocking).
class _AthletePicker extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  const _AthletePicker({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final athletes = context.watch<HomeProvider>().athletes;
    if (athletes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(
          'Add a child from Profile to book for them.',
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: athletes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = athletes[i] as Map;
          final id = a['_id']?.toString();
          final name = (a['firstName'] ?? a['name'] ?? 'Athlete').toString();
          final on = id == selectedId;
          return GestureDetector(
            onTap: () => onChanged(id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? AppColors.slate : AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(
                  color: on ? Colors.transparent : AppColors.hairline,
                ),
              ),
              child: Text(
                name,
                style: AppTypography.font(
                  color: on ? AppColors.onSlate : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _fmtSlotDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return 'Date unavailable';
  const months = [
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
  const dows = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return '${dows[d.weekday % 7]}, ${months[d.month - 1]} ${d.day}';
}

void _snack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.negative : AppColors.slate,
    ),
  );
}

// ── Group seat tab ──────────────────────────────────────────────────────────

class _GroupTab extends StatefulWidget {
  final String serviceId;
  final MultiBookingController controller;
  final ScrollController scrollController;
  const _GroupTab({
    required this.serviceId,
    required this.controller,
    required this.scrollController,
  });

  @override
  State<_GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends State<_GroupTab> {
  String? _athleteId;
  String? _claimingKey; // "date|time" currently in flight

  @override
  Widget build(BuildContext context) {
    final slots = widget.controller.slots;
    if (slots.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No open slots right now',
        message: 'Check back soon — the coach\'s schedule refreshes weekly.',
      );
    }
    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      itemCount: slots.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          final athletes = context.watch<HomeProvider>().athletes;
          if (athletes.isNotEmpty && _athleteId == null) {
            _athleteId = (athletes.first as Map)['_id']?.toString();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _AthletePicker(
              selectedId: _athleteId,
              onChanged: (id) => setState(() => _athleteId = id),
            ),
          );
        }
        final slot = slots[i - 1];
        final date = slot['date']?.toString() ?? '';
        final time = slot['startTime']?.toString() ?? '';
        final capacity = (slot['capacity'] is num)
            ? (slot['capacity'] as num).toInt()
            : 1;
        final booked = widget.controller.bookedCount(date, time);
        final seatsLeft = (capacity - booked).clamp(0, capacity);
        final full = seatsLeft <= 0;
        final key = '$date|$time';
        final claiming = _claimingKey == key;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
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
                      _fmtSlotDate(date),
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      full
                          ? 'Full'
                          : seatsLeft == 1
                          ? '1 seat left'
                          : '$seatsLeft of $capacity seats left',
                      style: AppTypography.font(
                        color: full ? AppColors.negative : AppColors.slateText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: SporveButton(
                  full ? 'Full' : 'Claim seat',
                  size: SporveButtonSize.compact,
                  fullWidth: true,
                  loading: claiming,
                  onPressed: full
                      ? null
                      : () async {
                          setState(() => _claimingKey = key);
                          final athletes = context
                              .read<HomeProvider>()
                              .athletes;
                          final athlete =
                              athletes.firstWhere(
                                    (a) =>
                                        (a as Map)['_id']?.toString() ==
                                        _athleteId,
                                    orElse: () => const {},
                                  )
                                  as Map;
                          final id = await widget.controller.claimGroupSeat(
                            serviceId: widget.serviceId,
                            slotDate: date,
                            slotTime: time,
                            athleteId: _athleteId,
                            athleteFirstName:
                                (athlete['firstName'] ?? athlete['name'])
                                    ?.toString(),
                            athleteAgeBand: athlete['ageBand']?.toString(),
                          );
                          if (!context.mounted) return;
                          setState(() => _claimingKey = null);
                          if (id == null) {
                            // Honest failure (L-015): never silently no-op —
                            // most likely the slot filled while viewing.
                            _snack(
                              context,
                              widget.controller.actionError ??
                                  'That slot just filled up — pick another time.',
                              isError: true,
                            );
                          } else {
                            _snack(
                              context,
                              'Seat claimed for $time, ${_fmtSlotDate(date)}.',
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Recurring claim tab ─────────────────────────────────────────────────────

class _RecurringTab extends StatefulWidget {
  final String serviceId;
  final ScrollController scrollController;
  const _RecurringTab({
    required this.serviceId,
    required this.scrollController,
  });

  @override
  State<_RecurringTab> createState() => _RecurringTabState();
}

class _RecurringTabState extends State<_RecurringTab> {
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  int _dayOfWeek = 2; // Tue default
  String _time = '05:00 PM';
  int _occurrences = 8;
  String? _athleteId;
  bool _submitting = false;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: 'Request sent',
        message:
            'Your coach reviews recurring requests and confirms the standing '
            'spot — you\'ll see it on your schedule once approved.',
        actionLabel: 'Request another',
        onAction: () => setState(() => _sent = false),
      );
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      children: [
        _label('CHILD'),
        const SizedBox(height: 8),
        _AthletePicker(
          selectedId: _athleteId,
          onChanged: (id) => setState(() => _athleteId = id),
        ),
        const SizedBox(height: 18),
        _label('DAY OF WEEK'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (i) {
            final on = _dayOfWeek == i;
            return GestureDetector(
              onTap: () => setState(() => _dayOfWeek = i),
              child: Container(
                width: 44,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.slate : AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(
                    color: on ? Colors.transparent : AppColors.hairline,
                  ),
                ),
                child: Text(
                  _days[i],
                  style: AppTypography.font(
                    color: on ? AppColors.onSlate : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        _label('TIME'),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _times.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = _times[i];
              final on = _time == t;
              return GestureDetector(
                onTap: () => setState(() => _time = t),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: on ? AppColors.slate : AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    border: Border.all(
                      color: on ? Colors.transparent : AppColors.hairline,
                    ),
                  ),
                  child: Text(
                    t,
                    style: AppTypography.mono(
                      size: 12,
                      weight: FontWeight.w600,
                      color: on ? AppColors.onSlate : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _label('WEEKS'),
        const SizedBox(height: 8),
        Row(
          children: [
            _stepperButton(
              Icons.remove,
              onTap: _occurrences > 1
                  ? () => setState(() => _occurrences--)
                  : null,
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$_occurrences',
                textAlign: TextAlign.center,
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _stepperButton(
              Icons.add,
              onTap: _occurrences < 26
                  ? () => setState(() => _occurrences++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'The coach approves each recurring request before it\'s confirmed on '
          'your schedule.',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SporveButton(
          'Request ${_days[_dayOfWeek]}s $_time',
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }

  static const _times = [
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
    '07:00 PM',
  ];

  Widget _label(String text) => Text(
    text,
    style: AppTypography.font(
      color: AppColors.textTertiary,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
    ),
  );

  Widget _stepperButton(IconData icon, {VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final controller = context.read<MultiBookingController>();
    final athletes = context.read<HomeProvider>().athletes;
    final athlete =
        athletes.firstWhere(
              (a) => (a as Map)['_id']?.toString() == _athleteId,
              orElse: () => const {},
            )
            as Map;
    final today = DateTime.now();
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final id = await controller.createRecurringClaim({
      'serviceId': widget.serviceId,
      'dayOfWeek': _dayOfWeek,
      'startTime': _time,
      'startDate': iso(today),
      'cadence': 'weekly',
      'occurrenceCount': _occurrences,
      if (_athleteId != null) 'athleteId': _athleteId,
      if (athlete['firstName'] != null || athlete['name'] != null)
        'athleteFirstName': (athlete['firstName'] ?? athlete['name'])
            .toString(),
      if (athlete['ageBand'] != null) 'athleteAgeBand': athlete['ageBand'],
    });
    if (!mounted) return;
    setState(() => _submitting = false);
    if (id == null) {
      // Honest failure (L-015): show the real error, do not pretend it sent.
      _snack(
        context,
        controller.actionError ??
            "Couldn't send the request. Please try again.",
        isError: true,
      );
      return;
    }
    setState(() => _sent = true);
  }
}

// ── Pack credit tab ─────────────────────────────────────────────────────────

class _PackTab extends StatefulWidget {
  final String serviceId;
  final MultiBookingController controller;
  final ScrollController scrollController;
  const _PackTab({
    required this.serviceId,
    required this.controller,
    required this.scrollController,
  });

  @override
  State<_PackTab> createState() => _PackTabState();
}

class _PackTabState extends State<_PackTab> {
  String? _athleteId;
  String? _redeemingKey;

  @override
  Widget build(BuildContext context) {
    final balance = widget.controller.creditBalance;
    final slots = widget.controller.slots;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: 20,
                color: AppColors.slateText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  balance <= 0
                      ? 'No prepaid credits for this service yet.'
                      : balance == 1
                      ? '1 credit available'
                      : '$balance credits available',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Buying a pack is design-only (L-003) — clearly labeled, no charge.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.hairlineSoft),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buy a session pack',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Coming soon — pack purchases aren\'t live yet.',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: SporveButton(
                  'Notify me',
                  size: SporveButtonSize.compact,
                  variant: SporveButtonVariant.dark,
                  onPressed: () => _snack(
                    context,
                    "We'll let you know when session packs are available.",
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (balance > 0) ...[
          Text(
            'REDEEM A CREDIT',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          _AthletePicker(
            selectedId: _athleteId,
            onChanged: (id) => setState(() => _athleteId = id),
          ),
          const SizedBox(height: 12),
          if (slots.isEmpty)
            const EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No open slots to redeem against right now',
            )
          else
            for (final slot in slots) _redeemRow(context, slot),
        ],
      ],
    );
  }

  Widget _redeemRow(BuildContext context, Map<String, dynamic> slot) {
    final date = slot['date']?.toString() ?? '';
    final time = slot['startTime']?.toString() ?? '';
    final capacity = (slot['capacity'] is num)
        ? (slot['capacity'] as num).toInt()
        : 1;
    final booked = widget.controller.bookedCount(date, time);
    final full = booked >= capacity;
    final key = '$date|$time';
    final redeeming = _redeemingKey == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface2,
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
                    _fmtSlotDate(date),
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    full ? 'Full' : time,
                    style: AppTypography.font(
                      color: full
                          ? AppColors.negative
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 88,
              child: SporveButton(
                'Redeem',
                size: SporveButtonSize.compact,
                fullWidth: true,
                loading: redeeming,
                onPressed: full
                    ? null
                    : () async {
                        setState(() => _redeemingKey = key);
                        final athletes = context.read<HomeProvider>().athletes;
                        final athlete =
                            athletes.firstWhere(
                                  (a) =>
                                      (a as Map)['_id']?.toString() ==
                                      _athleteId,
                                  orElse: () => const {},
                                )
                                as Map;
                        final id = await widget.controller.redeemPackCredit(
                          serviceId: widget.serviceId,
                          slotDate: date,
                          slotTime: time,
                          athleteId: _athleteId,
                          athleteFirstName:
                              (athlete['firstName'] ?? athlete['name'])
                                  ?.toString(),
                          athleteAgeBand: athlete['ageBand']?.toString(),
                        );
                        if (!context.mounted) return;
                        setState(() => _redeemingKey = null);
                        if (id == null) {
                          _snack(
                            context,
                            widget.controller.actionError ??
                                "Couldn't redeem — you may be out of credits, or "
                                    "the slot just filled.",
                            isError: true,
                          );
                        } else {
                          _snack(
                            context,
                            'Credit redeemed for $time, ${_fmtSlotDate(date)}.',
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
