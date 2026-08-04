import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/org_grid_controller.dart';

/// Provider Model Rebuild — item #6 (a, deferred UI): the org's TRAINERS ×
/// VENUES scheduling grid for one week — a scannable read of every occupied
/// (venue × trainer × slot) across the org's services, with booked/capacity
/// counts and the DB-computed venue-conflict flag (org_schedule_grid,
/// 20260729_000600). Admin-gated at the DB: a non-admin caller's read is an
/// empty list by design (same L-005/L-024-flavored honest-empty-state pattern
/// as the camp roster) — this screen renders ONE empty state either way, it
/// never claims "you're not an admin" (the app can't tell those apart, and
/// shouldn't pretend to).
class ProviderOrgGridScreen extends StatefulWidget {
  const ProviderOrgGridScreen({super.key});

  @override
  State<ProviderOrgGridScreen> createState() => _ProviderOrgGridScreenState();
}

class _ProviderOrgGridScreenState extends State<ProviderOrgGridScreen> {
  late final OrgGridController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OrgGridController(context.read());
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrgGridController>.value(
      value: _controller,
      child: GradientScaffold(
        body: SafeArea(
          child: Consumer<OrgGridController>(
            builder: (context, c, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _header(),
                const SizedBox(height: 12),
                _weekPicker(c),
                if (!c.loading && !c.error && c.hasAnyConflict) ...[
                  const SizedBox(height: 10),
                  _conflictBanner(),
                ],
                const SizedBox(height: 12),
                Expanded(child: _body(c)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
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
                  'Org schedule grid',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'TRAINERS × VENUES · ONE WEEK',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekPicker(OrgGridController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _weekNavBtn(Icons.chevron_left, () => c.shiftWeek(-1)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: AppColors.hairlineStrong),
              ),
              child: Text(
                '${_fmtDate(c.fromDate)} – ${_fmtDate(c.toDate)}',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _weekNavBtn(Icons.chevron_right, () => c.shiftWeek(1)),
        ],
      ),
    );
  }

  Widget _weekNavBtn(IconData icon, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: icon == Icons.chevron_left ? 'Previous week' : 'Next week',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        onTap: onTap,
        child: Container(
          height: 44,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.hairlineStrong),
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _conflictBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.negativeTint,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.negative),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: AppColors.negative),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'One or more venues are double-booked by two different services '
                'at the same time — resolve by moving one trainer.',
                style: AppTypography.font(
                  color: AppColors.negative,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(OrgGridController c) {
    if (c.loading && c.rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.slateText,
          strokeWidth: 2,
        ),
      );
    }
    if (c.error) {
      return ErrorRetry(
        message: "We couldn't load the schedule grid. Please try again.",
        onRetry: () => c.load(),
      );
    }
    if (c.rows.isEmpty) {
      // One honest empty state either way — org-admin-with-nothing-booked and
      // non-admin look identical to the app (the DB gate, not this screen,
      // decides who sees rows). Same stance as the camp roster (L-005/L-024).
      return const EmptyState(
        icon: Icons.grid_view_outlined,
        title: 'Nothing on the grid this week',
        message: "Either your org has no venue-pinned bookings in this week, "
            "or you're not an org admin. Ask the org owner if you expect to "
            "see the schedule here.",
      );
    }
    final byVenue = c.byVenue;
    return RefreshIndicator(
      color: AppColors.slateText,
      backgroundColor: AppColors.surface,
      onRefresh: () => c.load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        children: [
          for (final entry in byVenue.entries) ...[
            _venueHeader(entry.key),
            const SizedBox(height: 8),
            for (final row in entry.value) ...[
              _cell(row),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _venueHeader(String venue) {
    return Row(
      children: [
        const Icon(Icons.place_outlined, size: 14, color: AppColors.slateText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            venue.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(Map<String, dynamic> r) {
    final conflict = r['hasConflict'] == true;
    final trainer = (r['trainerName'] ?? 'Any available').toString();
    final service = (r['serviceTitle'] ?? 'Service').toString();
    final booked = (r['booked'] as num?)?.toInt() ?? 0;
    final capacity = (r['capacity'] as num?)?.toInt() ?? 1;
    final full = booked >= capacity;

    return Semantics(
      label: conflict
          ? '$service, $trainer, ${_fmtDate(r['date']?.toString() ?? '')} '
              '${_fmtTime(r['slotTime']?.toString() ?? '')}, venue conflict'
          : '$service, $trainer, ${_fmtDate(r['date']?.toString() ?? '')} '
              '${_fmtTime(r['slotTime']?.toString() ?? '')}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: conflict ? AppColors.negative : AppColors.hairline,
            width: conflict ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDate(r['date']?.toString() ?? ''),
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtTime(r['slotTime']?.toString() ?? ''),
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          trainer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.font(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: full ? AppColors.slateTint : AppColors.hairlineSoft,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text(
                    '$booked/$capacity',
                    style: AppTypography.font(
                      color: full ? AppColors.slateText : AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (conflict) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.negativeTint,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    child: Text(
                      'CONFLICT',
                      style: AppTypography.font(
                        color: AppColors.negative,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mon = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${wd[d.weekday - 1]} ${mon[d.month - 1]} ${d.day}';
  }

  String _fmtTime(String hms) {
    final parts = hms.split(':');
    if (parts.length < 2) return hms.isEmpty ? '—' : hms;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hms;
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    final period = h >= 12 ? 'PM' : 'AM';
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }
}
