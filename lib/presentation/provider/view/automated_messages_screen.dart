import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../controllers/lifecycle_controller.dart';

/// Coach settings: an off / draft / auto selector per lifecycle event type.
/// Default is 'draft'. For non-logistics (substantive) types 'auto' is disabled,
/// because substantive messages always require coach approval.
class AutomatedMessagesScreen extends StatefulWidget {
  const AutomatedMessagesScreen({super.key});

  @override
  State<AutomatedMessagesScreen> createState() =>
      _AutomatedMessagesScreenState();
}

class _AutomatedMessagesScreenState extends State<AutomatedMessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LifecycleController>().loadPrefs(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LifecycleController>();
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(Icons.arrow_back, onTap: () => Get.back()),
        ),
        title: Text(
          'Automated messages',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ctrl.loadingPrefs
          ? const Center(
              child: SkeletonList(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Choose how each message is handled. Drafts wait in your approval '
                  'queue until you review and send them. Auto-send is only available '
                  'for logistics reminders.',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                for (final e in kLifecycleEvents) _eventCard(ctrl, e),
              ],
            ),
    );
  }

  Widget _eventCard(LifecycleController ctrl, LifecycleEvent e) {
    final mode = ctrl.modeFor(e.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.label,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            e.description,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _modeChip(ctrl, e, 'off', 'Off'),
              const SizedBox(width: 8),
              _modeChip(ctrl, e, 'draft', 'Draft'),
              const SizedBox(width: 8),
              _modeChip(ctrl, e, 'auto', 'Auto', enabled: e.isLogistics),
            ],
          ),
          if (!e.isLogistics) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Substantive messages always need your approval, so auto-send is off.',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (mode == 'auto') ...[
            const SizedBox(height: 10),
            Text(
              'Auto-sends a fixed reminder with only name, date, time and place.',
              style: AppTypography.font(
                color: AppColors.slateText,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(
    LifecycleController ctrl,
    LifecycleEvent e,
    String value,
    String label, {
    bool enabled = true,
  }) {
    final selected = ctrl.modeFor(e.type) == value;
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: !enabled
              ? null
              : () async {
                  if (selected) return;
                  final ok = await ctrl.setMode(e.type, value);
                  if (!mounted) return;
                  if (!ok) {
                    Get.snackbar(
                      'Not allowed',
                      'Auto-send is only available for logistics reminders.',
                      backgroundColor: AppColors.surface,
                      colorText: AppColors.textPrimary,
                    );
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.slateTint : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: selected ? AppColors.slateBorder : AppColors.hairline,
              ),
            ),
            child: Text(
              label,
              style: AppTypography.font(
                color: selected ? AppColors.slateText : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
