import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../provider/controllers/provider_controller.dart';
import '../widgets/common_widgets.dart';
import '../widgets/sporve_button.dart';
import 'controllers/onboard_draft_controller.dart';

/// Editable review of the AI draft. EVERY field is editable; nothing is saved or
/// published until the coach taps Save. claimsToVerify render unchecked in a
/// distinct section and are NOT added to the public profile unless confirmed.
class ProviderOnboardReviewScreen extends StatefulWidget {
  const ProviderOnboardReviewScreen({super.key});

  @override
  State<ProviderOnboardReviewScreen> createState() => _ProviderOnboardReviewScreenState();
}

class _ProviderOnboardReviewScreenState extends State<ProviderOnboardReviewScreen> {
  final _bio = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _addSpec = TextEditingController();
  final _addAge = TextEditingController();
  final _addSession = TextEditingController();

  List<String> _specialties = [];
  List<String> _ageGroups = [];
  List<String> _sessionTypes = [];
  List<String> _claims = [];
  List<bool> _claimChecked = [];
  String _priceRationale = '';
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    final d = context.read<OnboardDraftProvider>().draft;
    if (d != null && d.isNotEmpty) {
      _hasDraft = true;
      _bio.text = (d['bio'] ?? '').toString();
      _specialties = _strList(d['specialties']);
      _ageGroups = _strList(d['ageGroupsServed']);
      _sessionTypes = _strList(d['sessionTypes']);
      _claims = _strList(d['claimsToVerify']);
      _claimChecked = List<bool>.filled(_claims.length, false);
      final spr = d['suggestedPriceRange'];
      if (spr is Map) {
        _min.text = (spr['min'] ?? '').toString();
        _max.text = (spr['max'] ?? '').toString();
        _priceRationale = (spr['rationale'] ?? '').toString();
      }
    }
  }

  List<String> _strList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList() : <String>[];

  @override
  void dispose() {
    for (final c in [_bio, _min, _max, _addSpec, _addAge, _addSession]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final c = context.read<ProviderController>();
    // Persist what maps to real columns: bio + specialties (providers.sports).
    // claimsToVerify are NEVER auto-written to the public profile; the price is a
    // suggestion only and is set per-program at listing time (no provider price
    // column). This is an explicit, coach-initiated save.
    final ok = await c.saveMyProvider({
      'bio': _bio.text.trim(),
      'sports': List<String>.from(_specialties),
    });
    if (!mounted) return;
    if (ok) {
      context.read<OnboardDraftProvider>().reset();
      Get.snackbar('Saved', 'Your profile was updated.',
          backgroundColor: AppColors.positive, colorText: AppColors.onSlate,
          snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
      Get.offNamed(AppRoutes.providerMainNav);
    } else {
      Get.snackbar('Error', c.profileError ?? 'Could not save. Please try again.',
          backgroundColor: AppColors.negative, colorText: AppColors.textPrimary,
          snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ProviderController>();
    if (!_hasDraft) {
      return GradientScaffold(
        body: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('No draft to review.', style: AppTypography.font(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              SporveButton('Back', onPressed: () => Get.back(), variant: SporveButtonVariant.dark, fullWidth: false),
            ]),
          ),
        ),
      );
    }
    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review your draft',
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Everything here is editable. Nothing is saved or published until you tap Save.',
                  style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 24),

              _label('BIO'),
              const SizedBox(height: 8),
              _field(_bio, hint: 'Your bio…', maxLines: 5),
              const SizedBox(height: 24),

              _tagSection('SPECIALTIES', _specialties, _addSpec),
              const SizedBox(height: 24),
              _tagSection('AGE GROUPS SERVED', _ageGroups, _addAge),
              const SizedBox(height: 24),
              _tagSection('SESSION TYPES', _sessionTypes, _addSession),
              const SizedBox(height: 24),

              _priceCard(),
              const SizedBox(height: 24),

              if (_claims.isNotEmpty) ...[_claimsCard(), const SizedBox(height: 24)],

              SporveButton('Save to my profile',
                  onPressed: c.savingProfile ? null : _save, loading: c.savingProfile,
                  variant: SporveButtonVariant.primary, icon: Icons.check),
              const SizedBox(height: 10),
              Center(
                child: Text('You’re in control — review and edit freely before saving.',
                    style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Suggested price (suggestion only, editable, never auto-applied) ─────────
  Widget _priceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('SUGGESTED PRICE',
                style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.chip), border: Border.all(color: AppColors.slateBorder)),
              child: Text('SUGGESTION', style: AppTypography.font(color: AppColors.slateText, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _numField(_min, 'Min \$')),
            const SizedBox(width: 12),
            Expanded(child: _numField(_max, 'Max \$')),
          ]),
          if (_priceRationale.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_priceRationale, style: AppTypography.font(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Text('A suggestion only — never applied automatically. You set the actual price per program when you create a listing.',
              style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }

  // ── claimsToVerify — distinct, unchecked, not published until confirmed ─────
  Widget _claimsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify before these appear on your profile',
              style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Certifications, experience, and credentials need verification. Unchecked items are NOT added to your public profile.',
              style: AppTypography.font(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          for (int i = 0; i < _claims.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  height: 24, width: 24,
                  child: Checkbox(
                    value: _claimChecked[i],
                    onChanged: (v) => setState(() => _claimChecked[i] = v ?? false),
                    activeColor: AppColors.slateText,
                    side: const BorderSide(color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(_claims[i], style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13, height: 1.4)),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Text('Confirming marks an item for verification — it still won’t publish until our review.',
              style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }

  Widget _tagSection(String label, List<String> list, TextEditingController addCtrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        if (list.isNotEmpty)
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
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
                      onTap: () => setState(() => list.removeAt(i)),
                      child: const Icon(Icons.close, color: AppColors.textTertiary, size: 14),
                    ),
                  ]),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field(addCtrl, hint: 'Add…', onSubmitted: (v) => _addTag(list, addCtrl))),
          const SizedBox(width: 8),
          SporveButton('Add', onPressed: () => _addTag(list, addCtrl),
              variant: SporveButtonVariant.secondary, onDark: true, size: SporveButtonSize.compact, fullWidth: false),
        ]),
      ],
    );
  }

  void _addTag(List<String> list, TextEditingController ctrl) {
    final v = ctrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      list.add(v);
      ctrl.clear();
    });
  }

  Widget _label(String text) => Text(text,
      style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0));

  Widget _numField(TextEditingController ctrl, String hint) {
    return _field(ctrl, hint: hint, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]);
  }

  Widget _field(TextEditingController ctrl,
      {required String hint, int maxLines = 1, TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters, ValueChanged<String>? onSubmitted}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
    );
  }
}
