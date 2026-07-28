import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

/// Final onboarding step: collect the child's REQUIRED date of birth + OPTIONAL
/// details, gate on explicit parental consent, then create the athlete.
/// Nothing is fabricated — unfilled optional fields are stored null.
class AlmostDoneScreen extends StatefulWidget {
  const AlmostDoneScreen({super.key});

  @override
  State<AlmostDoneScreen> createState() => _AlmostDoneScreenState();
}

class _AlmostDoneScreenState extends State<AlmostDoneScreen> {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  DateTime? _dob;
  String? _dobError;
  String? _genderLabel; // 'Male'|'Female'|'Other'|'Prefer not to say'|null
  final TextEditingController _medical = TextEditingController();
  final TextEditingController _emName = TextEditingController();
  final TextEditingController _emPhone = TextEditingController();
  String? _phoneError;
  bool _consent = false;

  @override
  void dispose() {
    _medical.dispose();
    _emName.dispose();
    _emPhone.dispose();
    super.dispose();
  }

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: "Child's date of birth",
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _dobError = _validateDob(picked);
    });
  }

  String? _validateDob(DateTime? dob) {
    if (dob == null) return 'Date of birth is required.';
    final now = DateTime.now();
    if (!dob.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'Date of birth must be in the past.';
    }
    final age = _ageFrom(dob);
    if (age > 100) return 'Please enter a valid date of birth.';
    if (age > 18) return 'Athlete must be under 18 for youth programs.';
    return null;
  }

  String? _validatePhone(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null; // optional
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^\+?[0-9 ()\-]{7,20}$').hasMatch(v) ||
        digits.length < 7 ||
        digits.length > 15) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  Future<void> _submit(OnboardingProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final dobErr = _validateDob(_dob);
    final phoneErr = _validatePhone(_emPhone.text);
    if (provider.fullName.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Please go back and enter the athlete\'s name.'),
        backgroundColor: AppColors.negative,
      ));
      return;
    }
    if (dobErr != null || phoneErr != null) {
      setState(() {
        _dobError = dobErr;
        _phoneError = phoneErr;
      });
      return;
    }

    // Push only REAL values into the provider; leave the rest null.
    provider.setAthleteDob(_dob!.toUtc().toIso8601String());
    final g = _genderLabel;
    if (g == 'Male' || g == 'Female' || g == 'Other') {
      provider.setAthleteGender(g!.toLowerCase());
    }
    if (_medical.text.trim().isNotEmpty) {
      provider.setAthleteMedicalConditions(_medical.text.trim());
    }
    final emName = _emName.text.trim();
    final emPhone = _emPhone.text.trim();
    if (emName.isNotEmpty || emPhone.isNotEmpty) {
      provider.setAthleteEmergencyContact({
        if (emName.isNotEmpty) 'name': emName,
        if (emPhone.isNotEmpty) 'phone': emPhone,
      });
    }

    final ok = await provider.submitAthleteProfile();
    if (ok) {
      Get.offAllNamed(AppRoutes.mainNav);
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Couldn\'t create the profile. Please try again.'),
        backgroundColor: AppColors.negative,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final dobLabel = _dob == null
        ? 'Select date of birth'
        : '${_months[_dob!.month - 1]} ${_dob!.day}, ${_dob!.year}';
    final canSubmit = _consent && !provider.isLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text('STEP 4 OF 4',
                  style: AppTypography.font(
                      color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Almost done',
                style: AppTypography.font(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              provider.fullName.isEmpty
                  ? 'A few details about your child'
                  : 'A few details about ${provider.fullName}',
              style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // ── Date of birth (REQUIRED) ──
            _label('DATE OF BIRTH', required: true),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDob,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(
                      color: _dobError != null ? AppColors.destructiveRed : AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.slateText, size: 18),
                    const SizedBox(width: 12),
                    Text(dobLabel,
                        style: AppTypography.font(
                            color: _dob == null ? AppColors.textTertiary : AppColors.textPrimary,
                            fontSize: 15)),
                  ],
                ),
              ),
            ),
            if (_dobError != null) _errorText(_dobError!),
            _helper('Used to match age-appropriate programs.'),
            const SizedBox(height: 20),

            // ── Gender (OPTIONAL) ──
            _label('GENDER (OPTIONAL)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Male', 'Female', 'Other', 'Prefer not to say']
                  .map((g) => _choiceChip(g, _genderLabel == g, () {
                        setState(() => _genderLabel = _genderLabel == g ? null : g);
                      }))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ── Medical (OPTIONAL) ──
            _label('MEDICAL CONDITIONS / ALLERGIES (OPTIONAL)'),
            const SizedBox(height: 8),
            _input(_medical, 'e.g. asthma, peanut allergy', maxLines: 2),
            _helper('Shared only with coaches you book, for your child\'s safety.'),
            const SizedBox(height: 20),

            // ── Emergency contact (OPTIONAL) ──
            _label('EMERGENCY CONTACT (OPTIONAL)'),
            const SizedBox(height: 8),
            _input(_emName, 'Contact name'),
            const SizedBox(height: 10),
            _input(_emPhone, 'Contact phone', keyboardType: TextInputType.phone,
                onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            }),
            if (_phoneError != null) _errorText(_phoneError!),
            _helper('Shared only with coaches you book, for your child\'s safety.'),
            const SizedBox(height: 24),

            // ── Parental consent gate (un-prechecked) ──
            GestureDetector(
              onTap: () => setState(() => _consent = !_consent),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(
                      color: _consent ? AppColors.slateBorder : AppColors.hairline),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_consent ? Icons.check_box : Icons.check_box_outline_blank,
                        color: _consent ? AppColors.slateText : AppColors.textTertiary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'I confirm I am the parent or legal guardian of this child and '
                        'consent to Sporve storing this information to provide youth '
                        'coaching services.',
                        style: AppTypography.font(
                            color: AppColors.textSecondary, fontSize: 12, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            SporveButton(
              'Create my profile',
              onPressed: canSubmit ? () => _submit(provider) : null,
              loading: provider.isLoading,
              variant: SporveButtonVariant.primary,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => Text(
        required ? '$text *' : text,
        style: AppTypography.font(
            color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
      );

  Widget _helper(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
      );

  Widget _errorText(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: AppTypography.font(color: AppColors.destructiveRed, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(color: selected ? AppColors.slateText : AppColors.hairline, width: 2),
          ),
          child: Text(label,
              style: AppTypography.font(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ),
      );

  Widget _input(TextEditingController c, String hint,
          {int maxLines = 1, TextInputType? keyboardType, ValueChanged<String>? onChanged}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: AppTypography.font(color: AppColors.textPrimary, fontSize: 15),
        cursorColor: AppColors.slateText,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 14),
          filled: true,
          fillColor: AppColors.surface2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            borderSide: const BorderSide(color: AppColors.slateBorder, width: 1.5),
          ),
        ),
      );
}
