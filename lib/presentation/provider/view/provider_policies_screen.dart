import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/coach_policies_controller.dart';

/// Coach OS — MY POLICIES (AI Front Office #3). The coach fills in the facts the
/// AI reply robot is allowed to cite: cancellation policy, what to bring, travel
/// radius, standing session notes, and a small FAQ. This is the ONLY source of
/// truth the draft-reply function may quote — so the value round-trips verbatim.
/// All fields are optional; a blank field is simply a fact the robot won't cite.
class ProviderPoliciesScreen extends StatefulWidget {
  const ProviderPoliciesScreen({super.key});

  @override
  State<ProviderPoliciesScreen> createState() => _ProviderPoliciesScreenState();
}

class _ProviderPoliciesScreenState extends State<ProviderPoliciesScreen> {
  final _cancellation = TextEditingController();
  final _whatToBring = TextEditingController();
  final _travelRadius = TextEditingController();
  final _sessionNotes = TextEditingController();

  // One controller pair per FAQ row, kept in sync with the controller's list.
  final List<_FaqRowControllers> _faqRows = [];
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = context.read<CoachPoliciesController>();
      await c.load();
      if (!mounted) return;
      _seedFromController(c);
    });
  }

  void _seedFromController(CoachPoliciesController c) {
    _cancellation.text = c.cancellationPolicy;
    _whatToBring.text = c.whatToBring;
    _travelRadius.text = c.travelRadius;
    _sessionNotes.text = c.sessionNotes;
    for (final r in _faqRows) {
      r.dispose();
    }
    _faqRows
      ..clear()
      ..addAll(c.faq.map((e) => _FaqRowControllers(
            question: e['question'] ?? '',
            answer: e['answer'] ?? '',
          )));
    setState(() => _seeded = true);
  }

  @override
  void dispose() {
    _cancellation.dispose();
    _whatToBring.dispose();
    _travelRadius.dispose();
    _sessionNotes.dispose();
    for (final r in _faqRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addFaqRow() {
    setState(() => _faqRows.add(_FaqRowControllers(question: '', answer: '')));
  }

  void _removeFaqRow(int index) {
    setState(() {
      _faqRows[index].dispose();
      _faqRows.removeAt(index);
    });
  }

  Future<void> _save() async {
    final c = context.read<CoachPoliciesController>();
    final messenger = ScaffoldMessenger.of(context);
    // Push the field values into the controller before persisting.
    c.cancellationPolicy = _cancellation.text;
    c.whatToBring = _whatToBring.text;
    c.travelRadius = _travelRadius.text;
    c.sessionNotes = _sessionNotes.text;
    c.faq
      ..clear()
      ..addAll(_faqRows.map((r) => {
            'question': r.question.text,
            'answer': r.answer.text,
          }));

    final ok = await c.save();
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Policies saved.'),
          backgroundColor: AppColors.slateText,
        ),
      );
    } else {
      // Honest failure — never fake success (L-015). The typed values remain in
      // the fields so the coach can retry.
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save your policies. Please try again."),
          backgroundColor: AppColors.negative,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CoachPoliciesController>();
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _header(),
            const SizedBox(height: 20),
            Expanded(child: _body(c)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
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
                'My policies',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'THE FACTS SPORVE ASSISTANT CAN CITE',
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
    );
  }

  Widget _body(CoachPoliciesController c) {
    if (c.loading && !_seeded) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.slateText,
          strokeWidth: 2,
        ),
      );
    }
    if (c.error && !_seeded) {
      return ErrorRetry(
        message: "We couldn't load your policies. Please try again.",
        onRetry: () async {
          await c.load();
          if (mounted) _seedFromController(c);
        },
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _note(
            'Only what you enter here can be quoted in an assistant reply. '
            'Leave a field blank and the assistant simply won\'t mention it.',
          ),
          const SizedBox(height: 24),
          _field(
            label: 'Cancellation policy',
            hint: 'e.g. 24-hour cancellation, otherwise charged in full',
            controller: _cancellation,
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _field(
            label: 'What to bring',
            hint: 'e.g. Cleats, shin guards, water bottle',
            controller: _whatToBring,
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _field(
            label: 'Travel radius',
            hint: 'e.g. Within 10 miles of downtown',
            controller: _travelRadius,
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _field(
            label: 'Session notes',
            hint: 'Standing notes about how your sessions run',
            controller: _sessionNotes,
            maxLines: 4,
          ),
          const SizedBox(height: 28),
          _faqSection(),
          const SizedBox(height: 32),
          SporveButton(
            'Save policies',
            onPressed: c.saving ? null : _save,
            loading: c.saving,
            variant: SporveButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  Widget _note(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTypography.font(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _faqSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('FREQUENTLY ASKED'),
            GestureDetector(
              onTap: _addFaqRow,
              child: Row(
                children: [
                  const Icon(Icons.add, size: 16, color: AppColors.slateText),
                  const SizedBox(width: 4),
                  Text(
                    'Add',
                    style: AppTypography.font(
                      color: AppColors.slateText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_faqRows.isEmpty)
          Text(
            'No FAQs yet. Add a question and answer the assistant can reuse.',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 12,
              height: 1.4,
            ),
          )
        else
          for (var i = 0; i < _faqRows.length; i++) _faqRow(i),
      ],
    );
  }

  Widget _faqRow(int index) {
    final row = _faqRows[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${index + 1}',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              GestureDetector(
                onTap: () => _removeFaqRow(index),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _bareField(row.question, 'Question (e.g. Do you offer trials?)'),
          const SizedBox(height: 8),
          Hairline(),
          const SizedBox(height: 8),
          _bareField(row.answer, 'Answer'),
        ],
      ),
    );
  }

  Widget _bareField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLines: null,
      style: AppTypography.font(
        color: AppColors.textPrimary,
        fontSize: 13,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.font(
          color: AppColors.textTertiary,
          fontSize: 13,
        ),
        border: InputBorder.none,
        isCollapsed: true,
      ),
    );
  }
}

class _FaqRowControllers {
  _FaqRowControllers({required String question, required String answer})
      : question = TextEditingController(text: question),
        answer = TextEditingController(text: answer);
  final TextEditingController question;
  final TextEditingController answer;

  void dispose() {
    question.dispose();
    answer.dispose();
  }
}
