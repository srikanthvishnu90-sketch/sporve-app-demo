import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/provider_controller.dart';
import '../../../core/config/env.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';

// Sporve is subscription-funded. Booking fee history is shown only when the
// payment webhook recorded it; missing values stay unknown.

class ProviderFinancesScreen extends StatefulWidget {
  const ProviderFinancesScreen({super.key});

  @override
  State<ProviderFinancesScreen> createState() => _ProviderFinancesScreenState();
}

class _ProviderFinancesScreenState extends State<ProviderFinancesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Per-transaction fee itemization (money page #2), loaded once from the
  // provider's own paid bookings. null = still loading; empty = nothing paid.
  List<ProviderTxn>? _txns;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Load real bookings + payouts + invoices so every tab reflects actual data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<ProviderController>();
      c.fetchProviderBookings();
      c.fetchPayouts();
      c.fetchInvoicing();
      _loadTxns();
    });
  }

  Future<void> _loadTxns() async {
    final txns = await context
        .read<ProviderController>()
        .transactionItemizations();
    if (!mounted) return;
    setState(() => _txns = txns);
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header Row
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
                        'Finances',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'EARNINGS & PAYOUTS',
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
            const SizedBox(height: 24),

            // Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.slateText,
              dividerColor: Colors.transparent,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textTertiary,
              labelStyle: AppTypography.font(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: AppTypography.font(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              tabs: const [
                Tab(text: 'DASHBOARD'),
                Tab(text: 'TRANSFERS'),
                Tab(text: 'TRANSACTIONS'),
                Tab(text: 'INVOICES'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildTransfersTab(),
                  _buildTransactionsTab(),
                  _buildInvoicesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    final c = context.watch<ProviderController>();
    final revenue = c.revenue;
    final revenueStr = '\$${revenue.toStringAsFixed(0)}';
    final athletes = c.rosterAthletes.length;
    var feeTotal = 0.0, beforeProcessingTotal = 0.0;
    for (final t in (_txns ?? const <ProviderTxn>[])) {
      if (t.feeKnown) feeTotal += t.fee;
      beforeProcessingTotal += t.feeKnown ? t.net : t.gross;
    }
    final beforeProcessingStr = '\$${beforeProcessingTotal.toStringAsFixed(0)}';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 2x2 summary grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _buildFinanceGridCard(
                label: 'REVENUE',
                value: revenueStr,
                trend: 'paid',
                trendColor: AppColors.warmAccent,
              ),
              _buildFinanceGridCard(
                label: 'ATHLETES',
                value: '$athletes',
                trend: '—',
                trendColor: AppColors.textTertiary,
              ),
              _buildFinanceGridCard(
                label: 'BEFORE PROCESSING',
                value: beforeProcessingStr,
                trend: 'after Sporve fee',
                trendColor: AppColors.textTertiary,
              ),
              _buildFinanceGridCard(
                label: 'SESSIONS',
                value: '${c.sessions.length}',
                trend: '—',
                trendColor: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Earnings overview white card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earnings overview',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  revenueStr,
                  style: AppTypography.mono(
                    size: 40,
                    weight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'TOTAL EARNED · ALL TIME',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                _buildProgressRow(
                  label: 'REVENUE',
                  amount: revenueStr,
                  progress: revenue > 0 ? 1 : 0,
                  color: AppColors.slateText,
                ),
                const SizedBox(height: 16),
                _buildProgressRow(
                  label: 'RECORDED SPORVE FEES',
                  amount: '\$${feeTotal.toStringAsFixed(0)}',
                  progress: revenue > 0 ? (feeTotal / revenue) : 0,
                  color: AppColors.negative,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Coach OS tools (P0 #3): tax-season export + waitlist ──────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach tools',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _coachToolRow(
                  icon: Icons.download_outlined,
                  title: 'Export for taxes',
                  subtitle: 'One-tap CSV per tax year — gross, fee, net',
                  onTap: _pickYearAndExport,
                ),
                const SizedBox(height: 10),
                _coachToolRow(
                  icon: Icons.people_alt_outlined,
                  title: 'Manage waitlist',
                  subtitle: 'Families waiting on your full programs',
                  onTap: () => Get.toNamed(AppRoutes.providerWaitlist),
                ),
                const SizedBox(height: 10),
                _coachToolRow(
                  icon: Icons.event_repeat_outlined,
                  title: 'Weekly slots',
                  subtitle: 'Your standing weekly availability',
                  onTap: () => Get.toNamed(AppRoutes.providerRecurringSlots),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _coachToolRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.slateTint,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Icon(icon, color: AppColors.slateText, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// One tap per tax year (money page #3): pick a year (or all-time), then build
  /// + present that year's paid-booking CSV. Honest "nothing yet" when empty.
  Future<void> _pickYearAndExport() async {
    final c = context.read<ProviderController>();
    final years = await c.availableEarningYears();
    if (!mounted) return;
    if (years.isEmpty) {
      Get.snackbar(
        'Nothing to export',
        'You have no paid sessions yet.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface2,
        colorText: AppColors.textPrimary,
      );
      return;
    }
    final int? choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Export for taxes',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final y in years)
              ListTile(
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.slateText,
                  size: 20,
                ),
                title: Text(
                  '$y',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                onTap: () => Navigator.pop(sctx, y),
              ),
            ListTile(
              leading: const Icon(
                Icons.all_inclusive,
                color: AppColors.slateText,
                size: 20,
              ),
              title: Text(
                'All time',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
              onTap: () => Navigator.pop(sctx, -1),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _exportEarnings(choice == -1 ? null : choice);
  }

  /// Build the earnings CSV from REAL paid bookings for [year] (null = all-time)
  /// and present it for export (copy + best-effort download). Read-only; no money.
  Future<void> _exportEarnings([int? year]) async {
    final result = await context.read<ProviderController>().exportEarnings(
      year: year,
    );
    if (!mounted) return;
    if (result == null) {
      Get.snackbar(
        'Nothing to export',
        year == null
            ? 'You have no paid sessions yet.'
            : 'No paid sessions in $year.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface2,
        colorText: AppColors.textPrimary,
      );
      return;
    }
    final s = result.summary;
    final gross = '\$${s.gross.toStringAsFixed(2)}';
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(
          'Earnings export',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.count} paid sessions · $gross gross',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: AppColors.hairline),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  result.csv,
                  style: AppTypography.mono(
                    size: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(
              'Close',
              style: AppTypography.font(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.csv));
              Navigator.pop(dctx);
              Get.snackbar(
                'Copied',
                'Earnings CSV copied to clipboard.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.surface2,
                colorText: AppColors.textPrimary,
              );
            },
            child: Text(
              'Copy CSV',
              style: AppTypography.font(
                color: AppColors.slateText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dctx);
              _downloadCsv(result.csv);
            },
            child: Text(
              'Download',
              style: AppTypography.font(
                color: AppColors.slateText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Best-effort download via a data: URI (opens/saves in the browser on web).
  /// On failure we fall back to the clipboard so the export is never lost.
  Future<void> _downloadCsv(String csv) async {
    final uri = Uri.dataFromString(csv, mimeType: 'text/csv', encoding: utf8);
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('earnings CSV download failed, falling back to clipboard: $e');
      launched = false;
    }
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: csv));
    }
    if (!mounted) return;
    Get.snackbar(
      launched ? 'Exported' : 'Copied',
      launched
          ? 'Earnings CSV opened for download.'
          : 'Download unavailable — CSV copied to clipboard instead.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }

  Widget _buildFinanceGridCard({
    required String label,
    required String value,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.mono(
                  size: 22,
                  weight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              OutlinePill(trend, color: trendColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required String amount,
    required double progress,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              amount,
              style: AppTypography.mono(
                size: 11,
                weight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.hairline,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTransfersTab() {
    final c = context.watch<ProviderController>();
    final connected = c.stripeChargesEnabled;
    final pending = c.pendingPayoutNet;
    final payouts = c.payouts;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAID BOOKINGS',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(pending),
            style: AppTypography.mono(
              size: 40,
              weight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gross after any recorded Sporve fee, before Stripe processing. '
            'Actual transfers appear below.',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTransfersBadge(
                connected ? 'PAYOUTS ENABLED' : 'NOT CONNECTED',
                isGreenDot: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Real payout history (money page #1) ──────────────────────────
          Text(
            'PAYOUTS TO YOUR BANK',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          if (!c.payoutsLoaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (c.payoutsError != null)
            ErrorRetry(message: c.payoutsError!, onRetry: c.fetchPayouts)
          else if (payouts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Center(
                child: Text(
                  connected
                      ? 'No bank payouts yet. Stripe transfers will appear here.'
                      : 'Connect payouts to start receiving transfers.',
                  textAlign: TextAlign.center,
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...payouts.map(_payoutRow),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// One REAL Stripe payout row (money page #1). Amount is minor units from
  /// Stripe; status is Stripe's own (paid / pending / in_transit / failed) so a
  /// pending transfer is never shown as completed.
  Widget _payoutRow(Map<String, dynamic> p) {
    final cents = (p['amountCents'] as num?)?.toInt() ?? 0;
    final status = (p['status']?.toString() ?? 'pending').toUpperCase();
    final isPaid = status == 'PAID';
    final last4 = p['bankLast4']?.toString();
    final arrival = p['arrivalDate'];
    String when = '';
    if (arrival is num) {
      final d = DateTime.fromMillisecondsSinceEpoch(arrival.toInt() * 1000);
      when =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last4 != null ? 'Bank •••• $last4' : 'Bank payout',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  when.isEmpty ? status : '$status • $when',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(cents / 100.0),
                style: AppTypography.mono(
                  size: 15,
                  weight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              OutlinePill(
                status,
                color: isPaid ? AppColors.slateText : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransfersBadge(String text, {bool isGreenDot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGreenDot) ...[
            Container(
              height: 6,
              width: 6,
              decoration: const BoxDecoration(
                color: AppColors.slateText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    // Recorded per-transaction itemization. Missing historical fee facts remain
    // unknown and are never recomputed from the current 0% policy.
    final txns = _txns;
    if (txns == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(
            color: AppColors.slateText,
            strokeWidth: 2,
          ),
        ),
      );
    }
    var gross = 0.0, fee = 0.0, beforeProcessing = 0.0, unknown = 0;
    for (final t in txns) {
      gross += t.gross;
      if (t.feeKnown) {
        fee += t.fee;
        beforeProcessing += t.net;
      } else {
        unknown++;
        beforeProcessing += t.gross;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _txnSummaryCard(
                  'GROSS (PAID)',
                  _money(gross),
                  AppColors.slateText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _txnSummaryCard(
                  'BEFORE PROCESSING',
                  _money(beforeProcessing),
                  AppColors.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recorded Sporve fees ${_money(fee)}. Sporve currently charges 0% '
            'per booking under workspace subscriptions. Stripe processing is '
            'separate.${unknown > 0 ? ' $unknown historical fee record${unknown == 1 ? ' is' : 's are'} unavailable.' : ''}',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: txns.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No paid sessions yet.',
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: txns.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: AppColors.hairline, height: 24),
                    itemBuilder: (context, index) => _txnRow(txns[index]),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _txnSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.mono(
              size: 22,
              weight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// One paid-booking row using only webhook-recorded money facts.
  Widget _txnRow(ProviderTxn t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.program.isEmpty ? 'Training session' : t.program,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (t.athlete.isNotEmpty) t.athlete,
                      t.date,
                      ?t.tierLabel,
                    ].join(' • '),
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _money(t.feeKnown ? t.net : t.gross),
              style: AppTypography.mono(
                size: 15,
                weight: FontWeight.bold,
                color: AppColors.successGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinePill(
              t.feeKnown ? 'SPORVE ${t.ratePct}' : 'FEE UNKNOWN',
              color: t.feeKnown ? AppColors.slateText : AppColors.textTertiary,
            ),
            const Spacer(),
            Flexible(
              child: Text(
                t.feeKnown
                    ? 'Gross ${_money(t.gross)}   −   Sporve ${_money(t.fee)}'
                    : 'Gross ${_money(t.gross)} · fee record unavailable',
                textAlign: TextAlign.right,
                style: AppTypography.mono(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoicesTab() {
    // Off-platform invoicing: creating/listing drafts is real and server-owned.
    // The live Stripe charge/send is FLAGGED OFF
    // (Env.offPlatformInvoicingCharge) with a test-mode plan (L-003) — a draft
    // moves no money.
    final c = context.watch<ProviderController>();
    final invoices = c.invoices;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Draft invoices for families you brought yourself. Sporve is '
            'subscription-funded; any historical fee shown below is the amount '
            'recorded by the server.',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SporveButton(
            'Create invoice',
            onPressed: _createInvoiceDialog,
            variant: SporveButtonVariant.primary,
            icon: Icons.add,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: invoices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No invoices yet.',
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: invoices.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: AppColors.hairline, height: 24),
                    itemBuilder: (context, index) =>
                        _invoiceRow(invoices[index]),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _invoiceRow(Map<String, dynamic> inv) {
    final status = (inv['status']?.toString() ?? 'draft').toUpperCase();
    final amount = ((inv['amountCents'] as num?)?.toInt() ?? 0) / 100.0;
    final fee = ((inv['applicationFeeCents'] as num?)?.toInt() ?? 0) / 100.0;
    Color statusColor;
    switch (status) {
      case 'PAID':
        statusColor = AppColors.successGreen;
        break;
      case 'OPEN':
        statusColor = AppColors.warmAccent;
        break;
      case 'VOID':
      case 'UNCOLLECTIBLE':
        statusColor = AppColors.negative;
        break;
      default: // DRAFT
        statusColor = AppColors.textTertiary;
    }
    final isDraft = status == 'DRAFT';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inv['contactName']?.toString() ?? 'Family',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inv['description']?.toString() ?? 'Off-platform',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(amount),
                  style: AppTypography.mono(
                    size: 15,
                    weight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                OutlinePill(status, color: statusColor),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Recorded Sporve fee ${_money(fee)} · before processing '
              '${_money(amount - fee)}',
              style: AppTypography.font(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            if (isDraft)
              TextButton(
                onPressed: () => _sendInvoiceStub(inv),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  Env.offPlatformInvoicingCharge ? 'Send' : 'Send (soon)',
                  style: AppTypography.font(
                    color: Env.offPlatformInvoicingCharge
                        ? AppColors.slateText
                        : AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Sending/charging an off-platform invoice is behind a flag with a test-mode
  /// plan (L-003). Until the flag + test proof land, this never charges — it
  /// tells the coach the draft is saved and sending is coming.
  void _sendInvoiceStub(Map<String, dynamic> inv) {
    if (!Env.offPlatformInvoicingCharge) {
      Get.snackbar(
        'Draft saved',
        'Sending invoices is being finalized — your draft is safe until then.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface2,
        colorText: AppColors.textPrimary,
      );
      return;
    }
    // Flag ON path (test mode only): the client would invoke coach-invoice-create
    // here. Left intentionally un-wired to the live charge in this change set —
    // the charge lands in the flagged, test-verified stripe-payments change.
    Get.snackbar(
      'Not available',
      'Invoice sending is enabled in test mode only in this build.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }

  /// Draft an off-platform invoice: capture the family + one line item, create a
  /// coach contact + a DRAFT invoice (money facts pinned server-side). No
  /// charge (L-003).
  Future<void> _createInvoiceDialog() async {
    final nameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final labelCtl = TextEditingController(text: 'Private session');
    final amountCtl = TextEditingController();
    final qtyCtl = TextEditingController(text: '1');
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialog) => AlertDialog(
          backgroundColor: AppColors.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          title: Text(
            'New invoice',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField('Family name', nameCtl),
                _dialogField(
                  'Email',
                  emailCtl,
                  keyboard: TextInputType.emailAddress,
                ),
                _dialogField('What for', labelCtl),
                Row(
                  children: [
                    Expanded(
                      child: _dialogField(
                        'Amount (\$)',
                        amountCtl,
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 70,
                      child: _dialogField(
                        'Qty',
                        qtyCtl,
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This saves a draft only; it does not move money. Sporve uses '
                  'workspace subscriptions, and Stripe processing is separate.',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dctx),
              child: Text(
                'Cancel',
                style: AppTypography.font(color: AppColors.textTertiary),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final name = nameCtl.text.trim();
                      final dollars = double.tryParse(amountCtl.text.trim());
                      final qty = int.tryParse(qtyCtl.text.trim()) ?? 1;
                      if (name.isEmpty || dollars == null || dollars <= 0) {
                        Get.snackbar(
                          'Check the details',
                          'Enter a family name and a positive amount.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.surface2,
                          colorText: AppColors.textPrimary,
                        );
                        return;
                      }
                      setDialog(() => busy = true);
                      final ctl = context.read<ProviderController>();
                      final contactId = await ctl.createContact({
                        'displayName': name,
                        'email': emailCtl.text.trim(),
                      });
                      String? invId;
                      if (contactId != null) {
                        invId = await ctl.createInvoiceDraft({
                          'contactId': contactId,
                          'description': labelCtl.text.trim(),
                          'currency': 'USD',
                          'lineItems': [
                            {
                              'label': labelCtl.text.trim(),
                              'qty': qty < 1 ? 1 : qty,
                              'unit_amount_cents': (dollars * 100).round(),
                            },
                          ],
                        });
                      }
                      if (!dctx.mounted) return;
                      Navigator.pop(dctx);
                      Get.snackbar(
                        invId != null ? 'Draft created' : 'Could not save',
                        invId != null
                            ? 'Invoice drafted — no charge yet.'
                            : 'Something went wrong. Please try again.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppColors.surface2,
                        colorText: AppColors.textPrimary,
                      );
                    },
              child: Text(
                busy ? 'Saving…' : 'Create draft',
                style: AppTypography.font(
                  color: AppColors.slateText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    nameCtl.dispose();
    emailCtl.dispose();
    labelCtl.dispose();
    amountCtl.dispose();
    qtyCtl.dispose();
  }

  Widget _dialogField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
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
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairline),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              cursorColor: AppColors.slateText,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderWithdrawalScreen extends StatefulWidget {
  const ProviderWithdrawalScreen({super.key});

  @override
  State<ProviderWithdrawalScreen> createState() =>
      _ProviderWithdrawalScreenState();
}

class _ProviderWithdrawalScreenState extends State<ProviderWithdrawalScreen> {
  String _selectedAmount = '1k';
  int _selectedBankIndex = 0; // 0 for Chase, 1 for BoA

  @override
  Widget build(BuildContext context) {
    // Calculated values
    double amount = 1000.00;
    if (_selectedAmount == '500') amount = 500.00;
    if (_selectedAmount == '2.5k') amount = 2500.00;
    if (_selectedAmount == '5k') amount = 5000.00;

    const double fee = 0;
    final double receive = amount - fee;

    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header Row
              Row(
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
                        'Finances',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'EARNINGS & PAYOUTS',
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
              const SizedBox(height: 32),

              // Available to withdraw
              Text(
                'AVAILABLE TO WITHDRAW',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$0.00',
                style: AppTypography.mono(
                  size: 32,
                  weight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Withdrawal amount Card input
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    Text(
                      'WITHDRAWAL AMOUNT',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$',
                            style: AppTypography.mono(
                              size: 32,
                              weight: FontWeight.bold,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            amount.toStringAsFixed(0),
                            style: AppTypography.mono(
                              size: 64,
                              weight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please enter an amount and select a bank.',
                      style: AppTypography.font(
                        color: AppColors.negative,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick amount selectors
              Builder(
                builder: (context) {
                  const amountKeys = ['500', '1k', '2.5k', '5k'];
                  const amountLabels = ['\$500', '\$1k', '\$2.5k', '\$5k'];
                  return SporveSegmented(
                    segments: amountLabels,
                    selected: amountKeys.indexOf(_selectedAmount),
                    onChanged: (i) {
                      setState(() {
                        _selectedAmount = amountKeys[i];
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 32),

              // Send to
              Text(
                'SEND TO',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),

              // Bank Cards
              _buildSelectableBankCard(
                index: 0,
                bankName: 'Chase Bank',
                details: 'Checking ****4821',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 12),
              _buildSelectableBankCard(
                index: 1,
                bankName: 'Bank of America',
                details: 'Savings ****7392',
                icon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: 32),

              // Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Withdrawal amount',
                      '\$${amount.toStringAsFixed(2)}',
                      AppColors.textPrimary,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'Sporve transfer fee',
                      '-\$${fee.toStringAsFixed(2)}',
                      AppColors.warning,
                    ),
                    const Divider(color: AppColors.hairline, height: 24),
                    _buildSummaryRow(
                      'You receive',
                      '\$${receive.toStringAsFixed(2)}',
                      AppColors.slateText,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Button
              SporveButton(
                'Payouts are not enabled',
                onPressed: null,
                variant: SporveButtonVariant.primary,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableBankCard({
    required int index,
    required String bankName,
    required String details,
    required IconData icon,
  }) {
    bool isSelected = _selectedBankIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBankIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isSelected ? AppColors.slateText : AppColors.hairline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bankName,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.slateText,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.check,
                  color: AppColors.onSlate,
                  size: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: AppTypography.mono(
            size: isBold ? 14 : 12,
            weight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
