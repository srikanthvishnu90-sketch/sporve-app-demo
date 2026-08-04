import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/camp_roster_controller.dart';

/// Provider Model Rebuild — item #7 (deferred UI): camp roster + tap check-in.
/// STAFF-ONLY (L-005/L-024): a non-staff caller's `campRoster()` returns an
/// EMPTY list by design — the DB (RLS + `camp_staff_can_access`) enforces this,
/// not this screen. So this view renders exactly one honest empty state for
/// "no rows" (staffed-with-none-registered and not-staffed look identical here
/// on purpose — that's the correct behavior, not a bug to special-case).
///
/// Emergency contact + allergy/medical are SENSITIVE minors' PII: this screen
/// deliberately has NO share/copy/export affordance anywhere.
class CampRosterScreen extends StatefulWidget {
  const CampRosterScreen({
    super.key,
    required this.serviceId,
    this.campTitle,
  });

  final String serviceId;
  final String? campTitle;

  @override
  State<CampRosterScreen> createState() => _CampRosterScreenState();
}

class _CampRosterScreenState extends State<CampRosterScreen> {
  late final CampRosterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CampRosterController(
      context.read(),
      serviceId: widget.serviceId,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CampRosterController>.value(
      value: _controller,
      child: GradientScaffold(
        body: SafeArea(
          child: Consumer<CampRosterController>(
            builder: (context, c, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _header(c),
                const SizedBox(height: 12),
                _dayPicker(c),
                const SizedBox(height: 12),
                Expanded(child: _body(c)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(CampRosterController c) {
    return Padding(
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
                  'Camp roster',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (widget.campTitle == null || widget.campTitle!.isEmpty)
                      ? 'STAFF-ONLY · TAP TO CHECK IN'
                      : '${widget.campTitle!.toUpperCase()} · STAFF-ONLY',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayPicker(CampRosterController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              onTap: () => _pickDay(c),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: AppColors.hairlineStrong),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: AppColors.slateText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fmtDate(c.day),
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _actionIconBtn(
            icon: Icons.summarize_outlined,
            label: 'Recap',
            onTap: c.roster.isEmpty || c.drafting ? null : () => _openRecapSheet(c),
          ),
          const SizedBox(width: 8),
          _actionIconBtn(
            icon: Icons.campaign_outlined,
            label: 'Broadcast',
            onTap: c.roster.isEmpty || c.drafting ? null : () => _openBroadcastSheet(c),
          ),
        ],
      ),
    );
  }

  Widget _actionIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Semantics(
      button: true,
      label: label,
      enabled: !disabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        onTap: onTap,
        child: Container(
          height: 44,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled ? AppColors.surface : AppColors.slateTint,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(
              color: disabled ? AppColors.hairline : AppColors.slateBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: disabled ? AppColors.textTertiary : AppColors.slateText,
          ),
        ),
      ),
    );
  }

  Widget _body(CampRosterController c) {
    if (c.loading && c.roster.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.slateText,
          strokeWidth: 2,
        ),
      );
    }
    if (c.error) {
      return ErrorRetry(
        message: "We couldn't load the roster. Please try again.",
        onRetry: () => c.load(),
      );
    }
    if (c.roster.isEmpty) {
      // Deliberately ONE empty state for "not staffed" and "no registrants
      // yet" — the DB gate returns 0 rows either way (L-005/L-024); this
      // screen never tries to distinguish them.
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'No campers to show',
        message: "Either no families are registered for this day yet, or "
            "you're not staffed on this camp. Ask the camp owner to add you "
            "as staff if you expect to see rosters here.",
      );
    }
    return RefreshIndicator(
      color: AppColors.slateText,
      backgroundColor: AppColors.surface,
      onRefresh: () => c.load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        itemCount: c.roster.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _rosterCard(c, c.roster[i]),
      ),
    );
  }

  Widget _rosterCard(CampRosterController c, Map<String, dynamic> r) {
    final rosterId = r['rosterId']?.toString() ?? '';
    final first = (r['athleteFirstName'] ?? '').toString();
    final name = first.isEmpty ? 'Camper' : first;
    final ageBand = (r['athleteAgeBand'] ?? '').toString();
    final medical = (r['medicalNotes'] ?? '').toString().trim();
    final emergency = r['emergencyContact'];
    final checkedInAt = r['checkedInAt'];
    final checkedIn = checkedInAt != null && checkedInAt.toString().isNotEmpty;
    final busy = c.isCheckingIn(rosterId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: checkedIn ? AppColors.slateBorder : AppColors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ageBand.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ageBand,
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _checkInBadge(checkedIn: checkedIn, at: checkedInAt),
            ],
          ),
          const SizedBox(height: 10),
          _piiRow(
            icon: Icons.contact_phone_outlined,
            label: 'Emergency contact',
            value: _fmtEmergency(emergency),
          ),
          if (medical.isNotEmpty) ...[
            const SizedBox(height: 6),
            _piiRow(
              icon: Icons.medical_information_outlined,
              label: 'Allergy / medical',
              value: medical,
              emphasize: true,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44, // >=44px tap target
            child: OutlinedButton(
              onPressed: rosterId.isEmpty || busy
                  ? null
                  : () async {
                      final ok = await c.checkIn(rosterId);
                      if (!mounted) return;
                      if (!ok) {
                        _toast("Couldn't check in $name. Try again.");
                      }
                    },
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    checkedIn ? AppColors.slateTint : Colors.transparent,
                side: BorderSide(
                  color: checkedIn ? AppColors.slateBorder : AppColors.hairlineStrong,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.slateText,
                      ),
                    )
                  : Text(
                      checkedIn ? 'Checked in — tap to refresh' : 'Check in',
                      style: AppTypography.font(
                        color: checkedIn
                            ? AppColors.slateText
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkInBadge({required bool checkedIn, dynamic at}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: checkedIn ? AppColors.slateTint : AppColors.hairlineSoft,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        checkedIn ? _fmtCheckInTime(at) : 'NOT IN',
        style: AppTypography.font(
          color: checkedIn ? AppColors.slateText : AppColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _piiRow({
    required IconData icon,
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    // No share/copy/export affordance anywhere on this row by design — this
    // data is minors' PII, staff-eyes-only (L-005/L-024).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color: emphasize ? AppColors.warning : AppColors.textTertiary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.font(
                  color: emphasize ? AppColors.warning : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── EOD recap draft ──────────────────────────────────────────────────────
  Future<void> _openRecapSheet(CampRosterController c) async {
    const skillOptions = [
      'Passing', 'Shooting', 'Footwork', 'Defense', 'Teamwork', 'Conditioning',
    ];
    final selected = <String>{};
    int? effort;
    final noteCtrl = TextEditingController();

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
                      "Today's recap",
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap what happened today — a DRAFT recap goes to every '
                      'registered family. You review and send each one; '
                      'nothing sends automatically.',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'SKILLS WORKED ON',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in skillOptions)
                          GestureDetector(
                            onTap: () => setSheet(() {
                              if (selected.contains(s)) {
                                selected.remove(s);
                              } else {
                                selected.add(s);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected.contains(s)
                                    ? AppColors.slateTint
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadii.chip),
                                border: Border.all(
                                  color: selected.contains(s)
                                      ? AppColors.slateBorder
                                      : AppColors.hairlineStrong,
                                ),
                              ),
                              child: Text(
                                s,
                                style: AppTypography.font(
                                  color: selected.contains(s)
                                      ? AppColors.slateText
                                      : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'EFFORT',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in const [1, 2, 3])
                          GestureDetector(
                            onTap: () => setSheet(
                                () => effort = effort == e ? null : e),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: effort == e
                                    ? AppColors.slateTint
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadii.chip),
                                border: Border.all(
                                  color: effort == e
                                      ? AppColors.slateBorder
                                      : AppColors.hairlineStrong,
                                ),
                              ),
                              child: Text(
                                const {1: 'Steady', 2: 'Solid', 3: 'Outstanding'}[e]!,
                                style: AppTypography.font(
                                  color: effort == e
                                      ? AppColors.slateText
                                      : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NOTE (OPTIONAL)',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        border: Border.all(color: AppColors.hairlineStrong),
                      ),
                      child: TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        maxLength: 280,
                        style: AppTypography.font(
                            color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          counterStyle: AppTypography.font(
                              color: AppColors.textTertiary, fontSize: 10),
                          hintText: 'Anything worth mentioning to families…',
                          hintStyle: AppTypography.font(
                              color: AppColors.textTertiary, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                        onPressed: (selected.isEmpty &&
                                effort == null &&
                                noteCtrl.text.trim().isEmpty)
                            ? null
                            : () async {
                                final navigator = Navigator.of(sheetCtx);
                                final result = await c.draftRecap(
                                  skills: selected.toList(),
                                  effort: effort,
                                  note: noteCtrl.text.trim().isEmpty
                                      ? null
                                      : noteCtrl.text.trim(),
                                );
                                if (navigator.mounted) navigator.pop();
                                if (!mounted) return;
                                _reportDraftResult(
                                  result,
                                  successField: 'created',
                                  successNoun: 'family draft',
                                  successNounPlural: 'family drafts',
                                );
                              },
                        child: Text(
                          'Draft recap for every family',
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
              ),
            );
          },
        );
      },
    );
    noteCtrl.dispose();
  }

  // ── Camp-wide broadcast draft ────────────────────────────────────────────
  Future<void> _openBroadcastSheet(CampRosterController c) async {
    final msgCtrl = TextEditingController();

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
                      'Broadcast to camp families',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every registered family gets this as a DRAFT in their '
                      'thread. You approve and send each one from the inbox — '
                      'nothing sends automatically.',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        border: Border.all(color: AppColors.hairlineStrong),
                      ),
                      child: TextField(
                        controller: msgCtrl,
                        maxLines: 4,
                        maxLength: 2000,
                        style: AppTypography.font(
                            color: AppColors.textPrimary, fontSize: 14),
                        onChanged: (_) => setSheet(() {}),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          counterStyle: AppTypography.font(
                              color: AppColors.textTertiary, fontSize: 10),
                          hintText: 'e.g. Bring water bottles tomorrow — it\'s '
                              'going to be a hot one!',
                          hintStyle: AppTypography.font(
                              color: AppColors.textTertiary, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                        onPressed: msgCtrl.text.trim().isEmpty
                            ? null
                            : () async {
                                final navigator = Navigator.of(sheetCtx);
                                final result =
                                    await c.draftBroadcast(msgCtrl.text.trim());
                                if (navigator.mounted) navigator.pop();
                                if (!mounted) return;
                                _reportDraftResult(
                                  result,
                                  successField: 'drafted',
                                  successNoun: 'family draft',
                                  successNounPlural: 'family drafts',
                                );
                              },
                        child: Text(
                          'Draft broadcast for every family',
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
              ),
            );
          },
        );
      },
    );
    msgCtrl.dispose();
  }

  // ── Shared draft-result reporting (L-015: honest success/failure, never
  // silent) ───────────────────────────────────────────────────────────────
  void _reportDraftResult(
    Map<String, dynamic> result, {
    required String successField,
    required String successNoun,
    required String successNounPlural,
  }) {
    final err = result['error'];
    if (err != null && err.toString().isNotEmpty) {
      _toast(err.toString());
      return;
    }
    final n = (result[successField] as num?)?.toInt() ?? 0;
    if (n <= 0) {
      _toast('No registered families to draft for yet.');
      return;
    }
    final noun = n == 1 ? successNoun : successNounPlural;
    _toast('$n $noun ready — review and send from your inbox.');
  }

  Future<void> _pickDay(CampRosterController c) async {
    final current = DateTime.tryParse(c.day) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Camp day',
    );
    if (picked == null) return;
    await c.setDay(_iso(picked));
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const mon = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${mon[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtCheckInTime(dynamic at) {
    final d = at is DateTime ? at : DateTime.tryParse(at?.toString() ?? '');
    if (d == null) return 'IN';
    var h = d.hour % 12;
    if (h == 0) h = 12;
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return 'IN · $h:${d.minute.toString().padLeft(2, '0')} $period';
  }

  String _fmtEmergency(dynamic emergency) {
    if (emergency is! Map || emergency.isEmpty) return 'Not on file';
    final name = (emergency['name'] ?? '').toString().trim();
    final phone = (emergency['phone'] ?? '').toString().trim();
    final relation = (emergency['relation'] ?? emergency['relationship'] ?? '')
        .toString()
        .trim();
    final parts = <String>[
      if (name.isNotEmpty) name,
      if (relation.isNotEmpty) '($relation)',
    ];
    final label = parts.join(' ');
    if (label.isEmpty && phone.isEmpty) return 'Not on file';
    if (phone.isEmpty) return label;
    if (label.isEmpty) return phone;
    return '$label · $phone';
  }

  void _toast(String msg) {
    Get.snackbar(
      'Camp roster',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }
}
