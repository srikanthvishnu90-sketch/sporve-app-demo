import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../shared/controllers/waitlist_controller.dart';
import '../../widgets/common_widgets.dart';

/// Coach OS — WAITLIST management (P0 #3). The coach's view of families waiting on
/// their full programs: triage, offer the next open spot, or remove. Promotion to
/// a real booking rides the normal booking flow (the family books the offered
/// slot) — this surface moves NO money. COPPA-safe: only a first name + age band.
class ProviderWaitlistScreen extends StatefulWidget {
  const ProviderWaitlistScreen({super.key});

  @override
  State<ProviderWaitlistScreen> createState() => _ProviderWaitlistScreenState();
}

class _ProviderWaitlistScreenState extends State<ProviderWaitlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WaitlistController>().loadForProvider();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<WaitlistController>();
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
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
                        'Waitlist',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'FAMILIES WAITING FOR A SPOT',
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
            ),
            const SizedBox(height: 20),
            Expanded(child: _body(c)),
          ],
        ),
      ),
    );
  }

  Widget _body(WaitlistController c) {
    if (c.loading && c.providerEntries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.slateText,
          strokeWidth: 2,
        ),
      );
    }
    if (c.error) {
      return ErrorRetry(
        message: "We couldn't load your waitlist. Please try again.",
        onRetry: () => c.loadForProvider(),
      );
    }
    final entries = c.providerEntries;
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: AppColors.textTertiary,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                'No one is waiting yet.\nWhen a full program fills up, interested '
                'families will appear here.',
                textAlign: TextAlign.center,
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.slateText,
      onRefresh: () => c.loadForProvider(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _entryCard(c, entries[i]),
      ),
    );
  }

  Widget _entryCard(WaitlistController c, Map<String, dynamic> e) {
    final id = e['_id']?.toString() ?? '';
    final name = (e['athleteFirstName']?.toString().trim().isNotEmpty ?? false)
        ? e['athleteFirstName'].toString()
        : 'Family';
    final program = e['programTitle']?.toString() ?? 'Program';
    final ageBand = e['athleteAgeBand']?.toString() ?? '';
    final note = e['note']?.toString() ?? '';
    final status = e['status']?.toString() ?? 'waiting';
    final offered = status == 'offered';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name + (ageBand.isNotEmpty ? '  ·  $ageBand' : ''),
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      program,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(offered),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '"$note"',
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (!offered)
                Expanded(
                  child: _actionBtn(
                    label: 'Offer spot',
                    filled: true,
                    onTap: () async {
                      final ok = await c.setStatus(id, 'offered');
                      _toast(ok
                          ? 'Spot offered — invite $name to book the open slot.'
                          : 'Could not update. Try again.');
                    },
                  ),
                ),
              if (!offered) const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  label: 'Remove',
                  filled: false,
                  onTap: () async {
                    final ok = await c.setStatus(id, 'cancelled');
                    _toast(ok ? 'Removed from waitlist.' : 'Could not update.');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool offered) {
    final color = offered ? AppColors.slateText : AppColors.warmAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        offered ? 'OFFERED' : 'WAITING',
        style: AppTypography.font(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.slate : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: filled ? AppColors.slate : AppColors.hairlineStrong,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.font(
            color: filled ? AppColors.onSlate : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    Get.snackbar(
      'Waitlist',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }
}
