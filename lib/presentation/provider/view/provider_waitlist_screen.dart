import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:get_storage/get_storage.dart';
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
  // Live-refreshes the offer countdown text (Provider Model Rebuild #8). No
  // animation/motion is used for the countdown itself — plain text re-render —
  // so this is unaffected by prefers-reduced-motion.
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WaitlistController>().loadForProvider();
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          for (final entry in entries) ...[
            _entryCard(c, entry),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
          _demandSignalsSection(),
        ],
      ),
    );
  }

  Widget _demandSignalsSection() {
    List<dynamic> signals = [];
    try {
      final box = GetStorage();
      signals = box.read('demand_signals') ?? [];
    } catch (_) {}

    if (signals.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_searching, color: AppColors.positive, size: 18),
              const SizedBox(width: 8),
              Text(
                'UNSERVED AREA DEMAND SIGNALS (${signals.length})',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Parents requesting coaches in regions where supply is thin:',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          for (final s in signals.take(5)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${s['sport'] ?? 'Any'} · ZIP ${s['zip'] ?? '60601'}',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    s['email']?.toString() ?? '',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.hairline, height: 8),
          ],
        ],
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
    // Provider Model Rebuild #8 — the offer LEDGER row for this entry (if any):
    // surfaces the drafted/sent/accepted state + the 24h countdown independent
    // of the entry's own status column.
    final offer = c.offerForEntry(id);

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
          if (offered && offer != null) ...[
            const SizedBox(height: 12),
            _offerStatusRow(offer),
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
          if (offered && offer != null && offer['status'] == 'drafted') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _actionBtn(
                label: 'Draft the offer message',
                filled: true,
                onTap: () async {
                  final offerId = offer['_id']?.toString() ?? '';
                  if (offerId.isEmpty) return;
                  final res = await c.draftOffer(offerId);
                  if (res['error'] != null) {
                    _toast(res['error'].toString());
                  } else if (res['skipped'] != null) {
                    _toast(res['skipped'].toString());
                  } else {
                    _toast('Draft ready — review and send it from your inbox.');
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Provider Model Rebuild #8 — offer state pill + expiry countdown. States:
  /// drafted (agent wrote the message, not yet sent to the family), sent (the
  /// family can now see + accept it), accepted (they claimed the seat).
  Widget _offerStatusRow(Map<String, dynamic> offer) {
    final offerStatus = offer['status']?.toString() ?? 'drafted';
    final label = switch (offerStatus) {
      'sent' => 'OFFER SENT',
      'accepted' => 'ACCEPTED',
      _ => 'DRAFTING OFFER',
    };
    final color = offerStatus == 'accepted'
        ? AppColors.slateText
        : AppColors.warmAccent;
    final countdown = offerStatus == 'accepted'
        ? null
        : _countdownText(offer['expiresAt']?.toString());
    return Semantics(
      label: countdown != null ? '$label, $countdown' : label,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Text(
              label,
              style: AppTypography.font(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (countdown != null)
            Text(
              countdown,
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  /// "3h 12m left" / "42m left" / "Offer expired" — never throws on a bad/missing
  /// timestamp (falls back to an empty countdown so the pill alone still shows).
  String? _countdownText(String? expiresAtIso) {
    if (expiresAtIso == null || expiresAtIso.isEmpty) return null;
    final t = DateTime.tryParse(expiresAtIso);
    if (t == null) return null;
    final remaining = t.difference(DateTime.now());
    if (remaining.isNegative) return 'Offer expired';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m left';
    return '${remaining.inMinutes}m left';
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
        height: 44,
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
