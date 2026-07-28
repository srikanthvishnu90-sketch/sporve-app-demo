import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/sport_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/home_controller.dart';

/// Edit the athlete/family profile — name, phone, preferred sports. Persists via
/// [HomeProvider.updateUserProfile].
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  late Set<String> _sports;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<HomeProvider>().userProfile ?? const {};
    _first = TextEditingController(text: (p['firstName'] ?? '').toString());
    _last = TextEditingController(text: (p['lastName'] ?? '').toString());
    _phone = TextEditingController(text: (p['phoneNumber'] ?? '').toString());
    _sports = ((p['preferredSports'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<HomeProvider>().updateUserProfile({
      'firstName': _first.text.trim(),
      'lastName': _last.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'preferredSports': _sports.toList(),
    });
    if (!mounted) return;
    Get.back();
    Get.snackbar(
      'Saved',
      'Your profile was updated.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(Icons.arrow_back, onTap: () => Get.back()),
        ),
        title: Text(
          'Edit Profile',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          _label('FIRST NAME'),
          _field(_first, 'First name'),
          const SizedBox(height: 20),
          _label('LAST NAME'),
          _field(_last, 'Last name'),
          const SizedBox(height: 20),
          _label('PHONE'),
          _field(_phone, '+1 (555) 000-0000', keyboard: TextInputType.phone),
          const SizedBox(height: 24),
          _label('PREFERRED SPORTS'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in SportColors.pickerNames)
                _sportChip(s, _sports.contains(s)),
            ],
          ),
          const SizedBox(height: 32),
          SporveButton(
            _saving ? 'Saving…' : 'Save changes',
            onPressed: _saving ? null : _save,
            variant: SporveButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: AppTypography.font(
        color: AppColors.textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _field(
    TextEditingController c,
    String hint, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      cursorColor: AppColors.slateText,
      style: AppTypography.font(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.font(
          color: AppColors.textTertiary,
          fontSize: 15,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          borderSide: const BorderSide(color: AppColors.slateText),
        ),
      ),
    );
  }

  Widget _sportChip(String sport, bool selected) {
    final c = SportColors.of(sport);
    return GestureDetector(
      onTap: () => setState(() {
        selected ? _sports.remove(sport) : _sports.add(sport);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.16) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? c : AppColors.hairline,
          ),
        ),
        child: Text(
          sport,
          style: AppTypography.font(
            color: selected ? c : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
