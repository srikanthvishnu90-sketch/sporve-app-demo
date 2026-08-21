import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../controllers/progress_updates_controller.dart';

/// Read-only parent view of a child's SENT coach updates (newest first). Pulls
/// from the same parent_updates record the coach approved + sent. No editing,
/// no actions — this is the family-facing surface.
class ProgressUpdatesScreen extends StatefulWidget {
  const ProgressUpdatesScreen({super.key});

  @override
  State<ProgressUpdatesScreen> createState() => _ProgressUpdatesScreenState();
}

class _ProgressUpdatesScreenState extends State<ProgressUpdatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressUpdatesController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ProgressUpdatesController>();
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
                  decoration: const BoxDecoration(color: AppColors.hairline, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              Text('Progress updates',
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Updates your coach has shared, newest first.',
                  style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 20),
              if (c.children.length > 1) ...[_childSelector(c), const SizedBox(height: 20)],
              if (c.loading)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: SkeletonList()))
              else if (c.children.isEmpty)
                _empty('No children on your account yet.')
              else if (c.updates.isEmpty)
                _empty('No updates yet for ${c.selectedChild?['firstName'] ?? 'this child'}. Your coach will share progress here after a session.')
              else
                ...c.updates.map(_updateCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _childSelector(ProgressUpdatesController c) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        for (final child in c.children)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => c.selectChild(child['_id']?.toString() ?? ''),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: child['_id']?.toString() == c.selectedChildId ? AppColors.slateText : AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                (child['firstName'] ?? 'Child').toString(),
                style: AppTypography.font(
                  color: child['_id']?.toString() == c.selectedChildId ? AppColors.onSlate : AppColors.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(msg, textAlign: TextAlign.center,
              style: AppTypography.font(color: AppColors.textTertiary, fontSize: 13, height: 1.5)),
        ),
      );

  Widget _updateCard(Map<String, dynamic> u) {
    final skills = (u['skillsWorked'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final suggestions = (u['practiceSuggestions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final summary = (u['summaryBody'] ?? '').toString();
    final progress = (u['progressSignal'] ?? '').toString();
    final encouragement = (u['encouragement'] ?? '').toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_fmtDate(u['sentAt'] ?? u['createdAt']),
              style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(summary, style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
          ],
          if (progress.isNotEmpty) ...[
            const SizedBox(height: 12),
            _miniLabel('PROGRESS'),
            const SizedBox(height: 4),
            Text(progress, style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
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
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: AppColors.textTertiary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13, height: 1.4))),
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
                  style: AppTypography.font(color: AppColors.slateDeep, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniLabel(String t) => Text(t,
      style: AppTypography.font(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0));

  Widget _chips(List<String> items) => Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          for (final s in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(s, style: AppTypography.font(color: AppColors.textPrimary, fontSize: 12)),
            ),
        ],
      );

  String _fmtDate(dynamic iso) {
    final d = DateTime.tryParse((iso ?? '').toString());
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}
