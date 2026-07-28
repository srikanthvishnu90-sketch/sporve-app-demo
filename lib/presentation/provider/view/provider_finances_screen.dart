import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/provider_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

/// Platform commission taken on each paid booking. Single source of truth for
/// the fee shown in the finances breakdown — de-magicked so the percentage and
/// the amount can never drift apart.
const double kPlatformFeeRate = 0.10; // 10%
final String kPlatformFeeLabel =
    '${(kPlatformFeeRate * 100).toStringAsFixed(0)}%';

class ProviderFinancesScreen extends StatefulWidget {
  const ProviderFinancesScreen({super.key});

  @override
  State<ProviderFinancesScreen> createState() => _ProviderFinancesScreenState();
}

class _ProviderFinancesScreenState extends State<ProviderFinancesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Load real bookings so revenue/earnings reflect actual paid sessions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderController>().fetchProviderBookings();
    });
  }

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
                label: 'PENDING PAYOUT',
                value: revenueStr,
                trend: '—',
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
                  label: 'PLATFORM FEE ($kPlatformFeeLabel)',
                  amount:
                      '\$${(revenue * kPlatformFeeRate).toStringAsFixed(0)}',
                  progress: revenue > 0 ? kPlatformFeeRate : 0,
                  color: AppColors.negative,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AVAILABLE BALANCE',
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
              size: 40,
              weight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Badge row
          Row(
            children: [_buildTransfersBadge('NOT CONNECTED', isGreenDot: true)],
          ),
          const SizedBox(height: 24),

          // Bullet points
          _buildBulletPoint(
            'Payments aren\'t connected yet — your balance will appear here once payouts are live.',
          ),
          const SizedBox(height: 12),
          _buildBulletPoint(
            'Once live, withdrawals will be processed through your linked bank account.',
          ),
          const SizedBox(height: 32),

          // Buttons
          SporveButton(
            'Bank payouts not enabled',
            onPressed: null,
            variant: SporveButtonVariant.primary,
            icon: Icons.lock_outline,
          ),
          // TODO(payments): "Deposit cash" + "Add bank account" hidden — they
          // only showed a "coming soon" snackbar and did nothing. Restore once
          // payments/bank-linking are live.
          const SizedBox(height: 32),

          // Linked accounts
          Text(
            'LINKED ACCOUNTS',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
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
                'No bank accounts linked yet.',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
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

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: AppColors.slateText,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(3),
          child: const Icon(Icons.check, color: AppColors.onSlate, size: 8),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    // No payments backend yet → no fabricated transactions. Real entries will
    // populate here once payment processing is connected; until then the empty
    // state below is shown.
    final List<Map<String, dynamic>> transactions = [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INCOME (30 DAYS)',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$0',
                        style: AppTypography.mono(
                          size: 24,
                          weight: FontWeight.bold,
                          color: AppColors.slateText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPENSES',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$0',
                        style: AppTypography.mono(
                          size: 24,
                          weight: FontWeight.bold,
                          color: AppColors.negative,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: transactions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No transactions yet.',
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
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: AppColors.hairline, height: 28),
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      final bool isCompleted = tx['status'] == 'COMPLETED';

                      return Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: SporveImage(
                                    tx['imageUrl'],
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    fallbackIcon: Icons.person,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  height: 14,
                                  width: 14,
                                  decoration: BoxDecoration(
                                    color: tx['isIncome']
                                        ? AppColors.successGreen
                                        : AppColors.negative,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        tx['name'],
                                        style: AppTypography.font(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinePill(
                                      tx['status'],
                                      color: isCompleted
                                          ? AppColors.successGreen
                                          : AppColors.warmAccent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${tx['type']} • ${tx['time']}',
                                  style: AppTypography.font(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            tx['amount'],
                            style: AppTypography.mono(
                              size: 15,
                              weight: FontWeight.bold,
                              color: tx['isIncome']
                                  ? AppColors.successGreen
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    // No invoicing backend yet → no fabricated invoices. Real invoices will
    // populate here once invoicing is live; until then the empty state shows.
    final List<Map<String, dynamic>> invoices = [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // TODO(payments): restore the "New invoice" action once invoice
          // creation is backed by a real service (hidden — it only showed a
          // "coming soon" snackbar and did nothing).
          const SizedBox(height: 16),
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
                        const Divider(color: AppColors.hairline, height: 28),
                    itemBuilder: (context, index) {
                      final inv = invoices[index];
                      Color statusColor;

                      if (inv['status'] == 'PAID') {
                        statusColor = AppColors.successGreen;
                      } else if (inv['status'] == 'PENDING') {
                        statusColor = AppColors.warmAccent;
                      } else {
                        statusColor = AppColors.negative;
                      }

                      return Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: SporveImage(
                                inv['imageUrl'],
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.person,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        inv['client'],
                                        style: AppTypography.font(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinePill(
                                      inv['status'],
                                      color: statusColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${inv['service']} • ${inv['due']}',
                                  style: AppTypography.font(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
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
                                inv['amount'],
                                style: AppTypography.mono(
                                  size: 15,
                                  weight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inv['invNo'],
                                style: AppTypography.mono(
                                  size: 11,
                                  weight: FontWeight.bold,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 40),
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

    double fee = amount * 0.0025;
    double receive = amount - fee;

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
                      'Transfer fee (0.25%)',
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
