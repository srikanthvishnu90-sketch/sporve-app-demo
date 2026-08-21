import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/utils/commission.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/sporve_button.dart';
import 'commission_itemization_card.dart';

/// Add / edit an affiliated trainer (Booksy model). Mirrors the create-listing
/// flow: name, specialty, price, duration, photo — plus the organization's share
/// (percent of revenue OR flat fee). background_check stays server-controlled,
/// so a new trainer is bookable/visible only after admin verification.
class CreateTrainerBottomSheet extends StatefulWidget {
  /// When editing, the existing member row (organization_members).
  final Map<String, dynamic>? member;
  const CreateTrainerBottomSheet({super.key, this.member});

  @override
  State<CreateTrainerBottomSheet> createState() =>
      _CreateTrainerBottomSheetState();
}

class _CreateTrainerBottomSheetState extends State<CreateTrainerBottomSheet> {
  late final TextEditingController _name;
  late final TextEditingController _specialty;
  late final TextEditingController _photo;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late final TextEditingController _flat;
  String _commissionType = 'percent';
  double _percent = 20;
  bool _saving = false;

  bool get _isEdit => widget.member != null;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    final p = (m?['trainer_profile'] as Map?) ?? const {};
    _name = TextEditingController(text: (p['display_name'] ?? '').toString());
    _specialty = TextEditingController(
      text: (p['specialty'] ?? p['bio'] ?? '').toString(),
    );
    _photo = TextEditingController(text: (p['photo_url'] ?? '').toString());
    _price = TextEditingController(text: (p['price'] ?? '').toString());
    _duration = TextEditingController(
      text: (p['duration_min'] ?? '60').toString(),
    );
    _commissionType = (m?['commission_type'] ?? 'percent').toString();
    final v = (m?['commission_value'] as num?)?.toDouble() ?? 20;
    if (_commissionType == 'percent') _percent = v.clamp(0, 100);
    _flat = TextEditingController(
      text: _commissionType == 'flat' ? v.toStringAsFixed(0) : '',
    );
    // Live math preview updates as the org edits the price or the flat fee.
    _price.addListener(_onPreviewInput);
    _flat.addListener(_onPreviewInput);
  }

  void _onPreviewInput() => setState(() {});

  /// The gross used for the live preview: the trainer's entered price, or a
  /// representative $80 session when blank (matches the spec example).
  int get _sampleGrossCents {
    final p = double.tryParse(_price.text.trim()) ?? 0;
    final cents = (p * 100).round();
    return cents > 0 ? cents : 8000;
  }

  double get _commissionValue => _commissionType == 'percent'
      ? _percent
      : (double.tryParse(_flat.text.trim()) ?? 0);

  /// The SHARED itemization (commission.dart) — the SAME shape the trainer sees.
  /// Shown for a REPEAT (recurring-rate) booking, the P0 unit; the intro-rate
  /// line differs only in the platform-fee slice.
  CommissionItemization get _preview => CommissionItemization.compute(
    grossCents: _sampleGrossCents,
    commissionType: commissionTypeFromString(_commissionType),
    commissionValue: _commissionValue,
    isFirst: false,
  );

  @override
  void dispose() {
    for (final c in [_name, _specialty, _photo, _price, _duration, _flat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      Get.snackbar(
        'Trainer name',
        'Please enter the trainer\'s name.',
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }
    setState(() => _saving = true);
    final commissionValue = _commissionType == 'percent'
        ? _percent
        : (double.tryParse(_flat.text.trim()) ?? 0);
    final payload = {
      'trainer_profile': {
        'display_name': _name.text.trim(),
        'specialty': _specialty.text.trim(),
        'bio': _specialty.text.trim(),
        'photo_url': _photo.text.trim(),
        'price': double.tryParse(_price.text.trim()) ?? 0,
        'duration_min': int.tryParse(_duration.text.trim()) ?? 60,
      },
      'role': 'trainer',
      'commission_type': _commissionType,
      'commission_value': commissionValue,
      'is_active': true,
    };
    final ctrl = context.read<ProviderController>();
    final ok = _isEdit
        ? await ctrl.updateTrainer(widget.member!['id'].toString(), payload)
        : await ctrl.createTrainer(payload);
    // EFFECTIVE-DATING (#5): on EDIT, append a NEW dated commission rate. Past
    // bookings keep their captured snapshot — this never rewrites history. On
    // create, the legacy member columns serve as the initial rate (the resolver
    // falls back to them until the first dated row exists).
    if (ok && _isEdit) {
      final prevType = (widget.member?['commission_type'] ?? 'percent')
          .toString();
      final prevVal =
          (widget.member?['commission_value'] as num?)?.toDouble() ?? 0;
      if (prevType != _commissionType || prevVal != commissionValue) {
        await ctrl.setCommission(
          widget.member!['id'].toString(),
          type: _commissionType,
          value: commissionValue,
        );
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Get.back();
      Get.snackbar(
        _isEdit ? 'Trainer updated' : 'Trainer added',
        'Bookable once their background check is verified.',
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } else {
      Get.snackbar(
        'Something went wrong',
        'Please try again.',
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: AppTypography.font(
      color: AppColors.textSecondary,
      fontSize: 13,
    ),
    filled: true,
    fillColor: AppColors.surface2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: const BorderSide(color: AppColors.hairline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: const BorderSide(color: AppColors.hairline),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                _isEdit ? 'Edit trainer' : 'Add a trainer',
                style: AppTypography.font(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: _dec('Trainer name'),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _specialty,
                decoration: _dec('Specialty / short description'),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _photo,
                decoration: _dec('Photo URL (optional)'),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: _dec('Price / session (\$)'),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      decoration: _dec('Duration (min)'),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Organization share',
                style: AppTypography.font(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The cut you keep from this trainer\'s bookings.',
                style: AppTypography.font(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // percent | flat toggle
              Row(
                children: [
                  _typeChip('percent', '% of revenue'),
                  const SizedBox(width: 8),
                  _typeChip('flat', 'Flat fee (\$)'),
                ],
              ),
              const SizedBox(height: 12),
              if (_commissionType == 'percent') ...[
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _percent,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        activeColor: AppColors.slate,
                        label: '${_percent.round()}%',
                        onChanged: (v) => setState(() => _percent = v),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${_percent.round()}%',
                        textAlign: TextAlign.right,
                        style: AppTypography.font(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                TextField(
                  controller: _flat,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Flat fee per session (\$)'),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              const SizedBox(height: 16),
              // LIVE MATH preview — the IDENTICAL itemization the trainer sees.
              CommissionItemizationCard(
                item: _preview,
                audience: CommissionAudience.org,
                sampleNote: _price.text.trim().isEmpty,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.history_toggle_off,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isEdit
                          ? 'A share change takes effect now. Already-booked sessions keep the rate they were booked at.'
                          : 'The share applies from now. You can change it later without affecting past bookings.',
                      style: AppTypography.font(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SporveButton(
                _saving
                    ? 'Saving…'
                    : (_isEdit ? 'Save changes' : 'Add trainer'),
                onPressed: _saving ? null : _save,
              ),
              if (_isEdit) ...[
                const SizedBox(height: 10),
                SporveButton(
                  'Remove trainer',
                  variant: SporveButtonVariant.destructive,
                  onPressed: _saving
                      ? null
                      : () async {
                          final id = widget.member!['id'].toString();
                          final ok = await context
                              .read<ProviderController>()
                              .deleteTrainer(id);
                          if (ok) Get.back();
                        },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _commissionType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _commissionType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.slate : AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(
              color: selected ? AppColors.slate : AppColors.hairline,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.font(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.onSlate : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
