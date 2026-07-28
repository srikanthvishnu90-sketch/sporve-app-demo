import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/home_controller.dart';

/// Opens the "Add a child" sheet. Returns true if a child was added.
///
/// COPPA-scoped intake (§7 / decision #10): first name, **birth year** (not a
/// full birthdate — minimize data), and a self-assessed level chip. Consent
/// renders at Body size, never as fine print.
Future<bool> showAddChildSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: const _AddChildSheet(),
    ),
  );
  return result ?? false;
}

/// The four self-assessed level chips (§7). `value` persists to
/// `athletes.skill_level` (lowercase); `desc` is the one-line self-calibration.
class _Level {
  final String value;
  final String label;
  final String desc;
  const _Level(this.value, this.label, this.desc);
}

const _levels = <_Level>[
  _Level('beginner', 'Beginner', 'New to the sport — learning the basics.'),
  _Level(
    'developing',
    'Developing',
    'Knows the fundamentals — building consistency.',
  ),
  _Level(
    'intermediate',
    'Intermediate',
    'Plays regularly — ready to refine skills.',
  ),
  _Level('advanced', 'Advanced', 'Competitive — training to reach further.'),
];

class _AddChildSheet extends StatefulWidget {
  const _AddChildSheet();

  @override
  State<_AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<_AddChildSheet> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  int? _birthYear;
  String? _skillLevel;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: AppColors.negative),
  );

  Future<void> _submit() async {
    final f = _first.text.trim();
    if (f.isEmpty) {
      _snack("Enter the child's first name.");
      return;
    }
    if (_birthYear == null) {
      _snack("Select the child's birth year.");
      return;
    }
    setState(() => _saving = true);
    // We collect only the year; store as Jan 1 of that year for the age gates.
    final dob = DateTime(_birthYear!, 1, 1).toIso8601String();
    final id = await context.read<HomeProvider>().addAthlete(
      firstName: f,
      lastName: _last.text.trim(),
      dateOfBirth: dob,
      skillLevel: _skillLevel,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id == null) {
      _snack("Couldn't add the child. Please try again.");
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = [for (int y = now.year - 4; y >= now.year - 18; y--) y];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Add a child',
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "We'll use this to book and track their sessions.",
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            _field('FIRST NAME', _first, 'Jordan'),
            const SizedBox(height: 16),
            _field('LAST NAME (OPTIONAL)', _last, 'Mercer'),
            const SizedBox(height: 20),

            // Birth YEAR — not a full birthdate (minimize data, §7).
            _label('BIRTH YEAR'),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: years.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _yearChip(years[i]),
              ),
            ),
            const SizedBox(height: 20),

            // Self-assessed level — four chips, each a one-line description.
            _label('SKILL LEVEL (OPTIONAL)'),
            const SizedBox(height: 10),
            for (final lvl in _levels) ...[
              _levelRow(lvl),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),

            // Consent at Body size — never fine print (§7 / §20).
            Text(
              "I'm this child's parent or legal guardian and I consent to Sporve "
              "collecting this information to match and book training. You can "
              "download or delete it anytime from Profile.",
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 22 / 15,
              ),
            ),
            const SizedBox(height: 20),
            SporveButton(
              _saving ? 'Adding…' : 'Add child',
              onPressed: _saving ? null : _submit,
              loading: _saving,
              variant: SporveButtonVariant.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTypography.font(
      color: AppColors.textTertiary,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
    ),
  );

  Widget _field(String label, TextEditingController c, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 15),
          cursorColor: AppColors.slateText,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(
                color: AppColors.slateBorder,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _yearChip(int year) {
    final selected = _birthYear == year;
    return GestureDetector(
      onTap: () => setState(() => _birthYear = selected ? null : year),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.slateText : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.hairline,
          ),
        ),
        child: Text(
          '$year',
          style: AppTypography.mono(
            size: 13,
            weight: FontWeight.w600,
            color: selected ? AppColors.onSlate : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _levelRow(_Level lvl) {
    final selected = _skillLevel == lvl.value;
    return GestureDetector(
      onTap: () =>
          setState(() => _skillLevel = selected ? null : lvl.value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.slateTint : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: selected ? AppColors.slateBorder : AppColors.hairline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lvl.label,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lvl.desc,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: selected ? AppColors.slateText : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
