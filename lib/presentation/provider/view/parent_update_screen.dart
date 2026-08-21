import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/parent_update_controller.dart';

/// "Write parent update" — coach notes -> AI draft (or clarify) -> editable,
/// autosaved draft -> explicit Approve. No parent-facing text leaves this screen
/// without the coach approving; approval and sending are deliberately separate.
class ParentUpdateScreen extends StatefulWidget {
  const ParentUpdateScreen({super.key});

  @override
  State<ParentUpdateScreen> createState() => _ParentUpdateScreenState();
}

class _ParentUpdateScreenState extends State<ParentUpdateScreen> {
  final _notes = TextEditingController();
  final _summary = TextEditingController();
  final _progress = TextEditingController();
  final _encourage = TextEditingController();
  final _addSkill = TextEditingController();
  final _addSuggestion = TextEditingController();
  final _addFocus = TextEditingController();
  final _progressNote = TextEditingController();
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentUpdateController>().init(
            bookingId: (args['bookingId'] ?? '').toString(),
            childId: (args['childId'] ?? '').toString(),
            childFirstName: (args['childFirstName'] ?? '').toString(),
            sport: (args['sport'] ?? '').toString(),
          );
    });
  }

  @override
  void dispose() {
    for (final c in [
      _notes,
      _summary,
      _progress,
      _encourage,
      _addSkill,
      _addSuggestion,
      _addFocus,
      _progressNote,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentUpdateController>();
    // Hydrate the editable text fields once when the draft first arrives.
    if (c.stage == ParentUpdateStage.draft && !_hydrated) {
      _summary.text = c.summaryBody;
      _progress.text = c.progressSignal;
      _encourage.text = c.encouragement;
      _hydrated = true;
    }
    if (c.stage != ParentUpdateStage.draft && c.stage != ParentUpdateStage.approved) {
      _hydrated = false;
    }

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
              Text('Write parent update',
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _contextRow(c),
              const SizedBox(height: 20),
              if (c.stage == ParentUpdateStage.input || c.stage == ParentUpdateStage.clarifying)
                _inputSection(c)
              else if (c.stage == ParentUpdateStage.draft)
                _draftSection(c)
              else if (c.stage == ParentUpdateStage.approved)
                _approvedSection(c)
              else
                _sentSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contextRow(ParentUpdateController c) {
    return Row(children: [
      Text(c.childFirstName.isEmpty ? 'Athlete' : c.childFirstName,
          style: AppTypography.font(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
      if (c.sport.isNotEmpty) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.chip), border: Border.all(color: AppColors.slateBorder)),
          child: Text(c.sport, style: AppTypography.font(color: AppColors.slateText, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    ]);
  }

  // ── Notes input (+ optional clarification questions) ────────────────────────
  Widget _inputSection(ParentUpdateController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.stage == ParentUpdateStage.clarifying && c.clarifyQuestions.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.warning),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('A few quick questions',
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Your notes were a little thin to write an honest update. Add detail below, then regenerate.',
                  style: AppTypography.font(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
              const SizedBox(height: 10),
              for (final q in c.clarifyQuestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.help_outline, size: 14, color: AppColors.slateText)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(q, style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13, height: 1.4))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 20),
        ],
        _label('SESSION NOTES'),
        const SizedBox(height: 6),
        Text('Type or tap your keyboard mic to dictate. Only what you write is used — nothing is invented.',
            style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
        const SizedBox(height: 8),
        _field(_notes, hint: 'e.g. Worked on dribbling and passing. Stayed focused, great energy…',
            maxLines: 6, onChanged: c.setRawNotes,
            prefix: const Icon(Icons.mic_none, color: AppColors.textTertiary, size: 18)),
        const SizedBox(height: 20),
        // Prompt 5: structured, provider-authored signals that feed the grounded
        // progress digest (parents never read these raw fields).
        _tagEditor('FOCUS AREAS', c.focusAreas, _addFocus, c.addFocusArea, c.removeFocusArea),
        const SizedBox(height: 20),
        _effortSelector(c),
        const SizedBox(height: 20),
        _label('PROGRESS NOTE (OPTIONAL)'),
        const SizedBox(height: 8),
        _field(_progressNote, hint: 'One honest line on progress this session…',
            maxLines: 2, onChanged: c.setProgressNote),
        const SizedBox(height: 20),
        SporveButton(
          c.stage == ParentUpdateStage.clarifying ? 'Regenerate draft' : 'Generate draft',
          onPressed: c.busy ? null : () => _generate(c),
          loading: c.busy,
          variant: SporveButtonVariant.primary,
          icon: Icons.auto_awesome,
        ),
        const SizedBox(height: 10),
        Center(child: Text('A draft only — nothing is sent to the parent here.',
            style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11))),
      ],
    );
  }

  Future<void> _generate(ParentUpdateController c) async {
    await c.generate();
    if (!mounted) return;
    if (c.error != null) {
      Get.snackbar('Draft', c.error!,
          backgroundColor: AppColors.surface, colorText: AppColors.textPrimary,
          snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
    }
  }

  // ── Editable draft ──────────────────────────────────────────────────────────
  Widget _draftSection(ParentUpdateController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(c.saving ? Icons.sync : Icons.cloud_done_outlined,
              size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(c.saving ? 'Saving…' : (c.lastSavedAt != null ? 'Draft saved' : 'Draft'),
              style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        _label('SUMMARY'),
        const SizedBox(height: 8),
        _field(_summary, hint: 'Parent-facing summary…', maxLines: 5, onChanged: c.editSummary),
        const SizedBox(height: 20),
        _tagEditor('SKILLS WORKED', c.skillsWorked, _addSkill, c.addSkill, c.removeSkill),
        const SizedBox(height: 20),
        _label('PROGRESS'),
        const SizedBox(height: 8),
        _field(_progress, hint: 'Honest progress signal…', maxLines: 2, onChanged: c.editProgress),
        const SizedBox(height: 20),
        _tagEditor('PRACTICE SUGGESTIONS', c.practiceSuggestions, _addSuggestion, c.addSuggestion, c.removeSuggestion),
        const SizedBox(height: 20),
        _label('ENCOURAGEMENT'),
        const SizedBox(height: 8),
        _field(_encourage, hint: 'A short, genuine note…', maxLines: 3, onChanged: c.editEncouragement),
        if (c.removed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Removed ${c.removed.length} line(s) your notes didn’t support — truthful over flattering.',
              style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
        ],
        const SizedBox(height: 24),
        SporveButton('Approve', onPressed: c.busy ? null : () => _approve(c), loading: c.busy,
            variant: SporveButtonVariant.primary, icon: Icons.check),
        const SizedBox(height: 10),
        Center(child: Text('Approving does not send. Sending is a separate step you control.',
            style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, height: 1.4), textAlign: TextAlign.center)),
      ],
    );
  }

  Future<void> _approve(ParentUpdateController c) async {
    final ok = await c.approve();
    if (!mounted) return;
    Get.snackbar(
      ok ? 'Approved' : 'Error',
      ok ? 'Update approved — ready to send when you choose.' : (c.error ?? 'Could not approve.'),
      backgroundColor: ok ? AppColors.positive : AppColors.negative,
      colorText: ok ? AppColors.onSlate : AppColors.textPrimary,
      snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16),
    );
  }

  Widget _approvedSection(ParentUpdateController c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.positive),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 22),
          const SizedBox(width: 10),
          Text('Approved', style: AppTypography.font(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Text('This update is approved and ready to send. You choose when it goes to the parent — sending is your explicit action.',
            style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        SporveButton('Send to parent', onPressed: c.busy ? null : () => _send(c), loading: c.busy,
            variant: SporveButtonVariant.primary, icon: Icons.send),
        const SizedBox(height: 10),
        SporveButton('Not now', onPressed: c.busy ? null : () => Get.back(), variant: SporveButtonVariant.dark),
      ]),
    );
  }

  Future<void> _send(ParentUpdateController c) async {
    final ok = await c.send();
    if (!mounted) return;
    if (!ok) {
      Get.snackbar('Send', c.error ?? 'Could not send.',
          backgroundColor: AppColors.negative, colorText: AppColors.textPrimary,
          snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
    }
  }

  Widget _sentSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.positive),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mark_email_read_outlined, color: AppColors.positive, size: 22),
          const SizedBox(width: 10),
          Text('Sent', style: AppTypography.font(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Text('The parent has been notified and can now see this update in their Progress updates.',
            style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        SporveButton('Back to schedule', onPressed: () => Get.back(), variant: SporveButtonVariant.dark),
      ]),
    );
  }

  // ── Shared builders (match the app's field/chip styling) ────────────────────
  Widget _tagEditor(String label, List<String> list, TextEditingController addCtrl,
      void Function(String) onAdd, void Function(int) onRemove) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      const SizedBox(height: 8),
      if (list.isNotEmpty)
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (int i = 0; i < list.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(list[i], style: AppTypography.font(color: AppColors.textPrimary, fontSize: 12)),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onRemove(i),
                  child: const Icon(Icons.close, color: AppColors.textTertiary, size: 14),
                ),
              ]),
            ),
        ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(addCtrl, hint: 'Add…', onSubmitted: (_) => _commitAdd(addCtrl, onAdd))),
        const SizedBox(width: 8),
        SporveButton('Add', onPressed: () => _commitAdd(addCtrl, onAdd),
            variant: SporveButtonVariant.secondary, onDark: true, size: SporveButtonSize.compact, fullWidth: false),
      ]),
    ]);
  }

  void _commitAdd(TextEditingController ctrl, void Function(String) onAdd) {
    final v = ctrl.text.trim();
    if (v.isEmpty) return;
    onAdd(v);
    ctrl.clear();
  }

  // Effort 1–5 (Prompt 5). Tap the selected value again to clear it.
  Widget _effortSelector(ParentUpdateController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('EFFORT (1–5)'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var v = 1; v <= 5; v++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => c.setEffort(v),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.effort == v ? AppColors.slateText : AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      border: Border.all(
                        color: c.effort == v ? AppColors.slateText : AppColors.hairline,
                      ),
                    ),
                    child: Text(
                      '$v',
                      style: AppTypography.font(
                        color: c.effort == v ? AppColors.onSlate : AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0));

  Widget _field(TextEditingController ctrl,
      {required String hint, int maxLines = 1, ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted, Widget? prefix}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (prefix != null) ...[Padding(padding: const EdgeInsets.only(top: 14), child: prefix), const SizedBox(width: 10)],
        Expanded(
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            cursorColor: AppColors.slateText,
            style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ]),
    );
  }
}
