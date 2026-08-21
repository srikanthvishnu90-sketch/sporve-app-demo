import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../controllers/athlete_timeline_controller.dart';
import 'milestone_card.dart';

/// The child's DEVELOPMENT TIMELINE (P0 #4 — the parent-side retention lock).
/// A reverse-chron rail merging the coach's SENT updates (skill tags + note) and
/// grounded progress digests into one development record — the artifact a text
/// thread can't replicate. Read-only; the coach authors upstream.
class AthleteTimelineScreen extends StatefulWidget {
  const AthleteTimelineScreen({super.key});

  @override
  State<AthleteTimelineScreen> createState() => _AthleteTimelineScreenState();
}

class _AthleteTimelineScreenState extends State<AthleteTimelineScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AthleteTimelineController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AthleteTimelineController>();
    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Get.back(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.hairline,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              Text('Development timeline',
                  style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Every session your coach logs, building your athlete’s record.',
                  style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4)),
              const SizedBox(height: 20),
              if (c.children.length > 1) ...[
                _childSelector(c),
                const SizedBox(height: 20),
              ],
              if (c.loading)
                const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: SkeletonList()))
              else if (c.error != null)
                _empty(c.error!)
              else if (c.children.isEmpty)
                _empty('No athletes on your account yet.')
              else if (c.entries.isEmpty)
                _empty(
                    'No entries yet for ${c.selectedChildName}. Your coach adds skills, notes and milestones here after each session.')
              else
                _timeline(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _childSelector(AthleteTimelineController c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final child in c.children)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => c.selectChild(child['_id']?.toString() ?? ''),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: child['_id']?.toString() == c.selectedChildId
                    ? AppColors.slate
                    : AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                (child['firstName'] ?? 'Child').toString(),
                style: AppTypography.font(
                  color: child['_id']?.toString() == c.selectedChildId
                      ? AppColors.onSlate
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _timeline(AthleteTimelineController c) {
    final entries = c.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++)
          _railRow(
            entry: entries[i],
            isFirst: i == 0,
            isLast: i == entries.length - 1,
            childName: c.selectedChildName,
          ),
      ],
    );
  }

  /// A left rail (node + connector) beside the artifact card.
  Widget _railRow({
    required TimelineEntry entry,
    required bool isFirst,
    required bool isLast,
    required String childName,
  }) {
    final isDigest = entry.kind == TimelineEntryKind.digest;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Top connector (hidden for the first node).
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst ? Colors.transparent : AppColors.hairlineStrong,
                ),
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: isDigest ? AppColors.surface2 : AppColors.slate,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDigest
                          ? AppColors.slateBorder
                          : AppColors.slate,
                      width: 2,
                    ),
                  ),
                ),
                // Bottom connector (hidden for the last node).
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        isLast ? Colors.transparent : AppColors.hairlineStrong,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FadeInUp(
                child: isDigest
                    ? _digestCard(entry)
                    : _updateCard(entry, childName),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardShell({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: child,
      );

  Widget _digestCard(TimelineEntry entry) {
    final body = (entry.data['body'] ?? '').toString();
    final counted = entry.data['sessionsCounted'];
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline,
                  size: 14, color: AppColors.chatAccent),
              const SizedBox(width: 6),
              Text('PROGRESS DIGEST',
                  style: AppTypography.font(
                      color: AppColors.chatAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0)),
              const Spacer(),
              Text(_fmtDate(entry.date),
                  style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body,
                style: AppTypography.font(
                    color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
          ],
          if (counted is int && counted > 0) ...[
            const SizedBox(height: 8),
            Text('Across $counted ${counted == 1 ? 'session' : 'sessions'}',
                style: AppTypography.font(
                    color: AppColors.textTertiary, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _updateCard(TimelineEntry entry, String childName) {
    final u = entry.data;
    final skills = (u['skillsWorked'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final suggestions = (u['practiceSuggestions'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final summary = (u['summaryBody'] ?? '').toString();
    final progress = (u['progressSignal'] ?? '').toString();
    final encouragement = (u['encouragement'] ?? '').toString();
    final headlineSkill = entry.headlineSkill;

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SESSION UPDATE',
                  style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0)),
              const Spacer(),
              Text(_fmtDate(entry.date),
                  style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(summary,
                style: AppTypography.font(
                    color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
          ],
          if (progress.isNotEmpty) ...[
            const SizedBox(height: 12),
            _miniLabel('PROGRESS'),
            const SizedBox(height: 4),
            Text(progress,
                style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4)),
          ],
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            _miniLabel('SKILLS WORKED'),
            const SizedBox(height: 6),
            _chips(skills),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _miniLabel('PRACTICE AT HOME'),
            const SizedBox(height: 6),
            ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle,
                                size: 5, color: AppColors.textTertiary)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(s,
                                style: AppTypography.font(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.4))),
                      ]),
                )),
          ],
          if (encouragement.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slateTint,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Text(encouragement,
                  style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                      fontStyle: FontStyle.italic)),
            ),
          ],
          if (headlineSkill != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openMilestone(
                childName: childName,
                milestone: headlineSkill,
                context: progress.isNotEmpty ? progress : summary,
                date: entry.date,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ios_share,
                      size: 15, color: AppColors.chatAccent),
                  const SizedBox(width: 6),
                  Text('Share as milestone',
                      style: AppTypography.font(
                          color: AppColors.chatAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openMilestone({
    required String childName,
    required String milestone,
    required String context,
    required DateTime date,
  }) {
    showMilestoneSheet(
      this.context,
      card: MilestoneCard(
        athleteName: childName,
        milestone: milestone,
        context: context,
        dateLabel: _fmtDate(date),
      ),
      onShare: () {
        Get.back();
        Get.snackbar(
          'Milestone ready',
          'Sharing opens in a later build — the card is saved to $childName’s timeline.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.surface2,
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16),
        );
      },
    );
  }

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(msg,
              textAlign: TextAlign.center,
              style: AppTypography.font(
                  color: AppColors.textTertiary, fontSize: 13, height: 1.5)),
        ),
      );

  Widget _miniLabel(String t) => Text(t,
      style: AppTypography.font(
          color: AppColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0));

  Widget _chips(List<String> items) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in items)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(s,
                  style: AppTypography.font(
                      color: AppColors.textPrimary, fontSize: 12)),
            ),
        ],
      );

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) {
    if (d.millisecondsSinceEpoch == 0) return '';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
