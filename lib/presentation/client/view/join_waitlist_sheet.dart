import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../shared/controllers/waitlist_controller.dart';
import '../../widgets/sporve_button.dart';

/// Client "join the waitlist" affordance (Coach OS, P0 #3). Shown when a program
/// is full so full-slot demand is CAPTURED instead of bouncing — the demand most
/// likely to convert into a repeat booking once a spot opens.
Future<void> showJoinWaitlistSheet(
  BuildContext context, {
  required Map<String, dynamic> program,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _JoinWaitlistSheet(program: program),
  );
}

/// True when a program has an explicit capacity and it is full. Reads both mapped
/// keys defensively (maxCapacity/enrolledCount are surfaced by _mapProgram and by
/// the mock). No capacity declared (0) => never "full" (open/unbounded).
bool programIsFull(Map<String, dynamic>? program) {
  if (program == null) return false;
  final maxCap = (program['maxCapacity'] as num?)?.toInt() ?? 0;
  final enrolled = (program['enrolledCount'] as num?)?.toInt() ?? 0;
  return maxCap > 0 && enrolled >= maxCap;
}

class _JoinWaitlistSheet extends StatefulWidget {
  const _JoinWaitlistSheet({required this.program});
  final Map<String, dynamic> program;

  @override
  State<_JoinWaitlistSheet> createState() => _JoinWaitlistSheetState();
}

class _JoinWaitlistSheetState extends State<_JoinWaitlistSheet> {
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final title = widget.program['title']?.toString() ?? 'this program';
    final id = await context.read<WaitlistController>().join({
      'programId': widget.program['_id'] ?? widget.program['programId'],
      'programTitle': title,
      'sport': widget.program['sportType'] ?? widget.program['sport'],
      'note': _noteCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
    if (id != null) {
      Get.snackbar(
        'On the waitlist',
        'We\'ll notify you if a spot opens for $title.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface2,
        colorText: AppColors.textPrimary,
      );
    } else {
      Get.snackbar(
        'Couldn\'t join',
        'Please try again in a moment.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface2,
        colorText: AppColors.textPrimary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.program['title']?.toString() ?? 'This program';
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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
          const SizedBox(height: 20),
          Text(
            'Join the waitlist',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$title is full right now. Join the waitlist and the coach can offer '
            'you the next open spot.',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'NOTE TO COACH (OPTIONAL)',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLength: 200,
            maxLines: 2,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. prefers Tuesday evenings',
              hintStyle: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.surface2,
              counterText: '',
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
                borderSide: const BorderSide(color: AppColors.slateText),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SporveButton(
              _submitting ? 'Joining…' : 'Join waitlist',
              onPressed: _submitting ? null : _submit,
              variant: SporveButtonVariant.primary,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}
