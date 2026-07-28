import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';

/// Fee figures shown in the payout breakdown, de-magicked into named constants
/// so the labels can't silently drift from the values billing actually uses.
/// The Sporve commission is the platform's own rate; the Stripe line is the
/// payment processor's published fee.
const double kPlatformCommissionRate = 0.10; // 10%
final String kPlatformCommissionLabel =
    '${(kPlatformCommissionRate * 100).toStringAsFixed(0)}%';
const String kStripeProcessingFeeLabel = '2.9% + \$0.30';

class ProviderPayoutsPaymentsScreen extends StatefulWidget {
  const ProviderPayoutsPaymentsScreen({super.key});

  @override
  State<ProviderPayoutsPaymentsScreen> createState() =>
      _ProviderPayoutsPaymentsScreenState();
}

class _ProviderPayoutsPaymentsScreenState
    extends State<ProviderPayoutsPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSchedule = 'Monthly'; // Daily, Weekly, Monthly

  // Bank accounts + payout history are real Stripe data — never fabricated.
  // Until the Stripe payouts feed is wired (a coach's connected account lists
  // these), these stay empty so the screen shows honest empty states instead of
  // fake "PAID" history with invented bank names.
  final List<Map<String, dynamic>> _banks = [];

  final List<Map<String, dynamic>> _payouts = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _routingController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default to Middle Tab (Bank Accounts, index 1) as shown in left image
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _routingController.dispose();
    _accountController.dispose();
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
                  Text(
                    'Payouts & Payments',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tab Bar
            TabBar(
              controller: _tabController,
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
                Tab(text: 'Payouts'),
                Tab(text: 'Bank Accounts'),
                Tab(text: 'Settings'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPayoutsTab(),
                  _buildBankAccountsTab(),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutsTab() {
    if (_payouts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No payouts yet.',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _payouts.length,
      itemBuilder: (context, index) {
        final payout = _payouts[index];
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
                      payout['bank'],
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payout['date'],
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
                    payout['amount'],
                    style: AppTypography.mono(
                      size: 15,
                      weight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinePill(
                    payout['status'] ?? 'PENDING',
                    color: payout['status'] == 'PAID'
                        ? AppColors.slateText
                        : AppColors.warning,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBankAccountsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your default account receives earnings within 1–2 business days via ACH.',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),

          // Bank cards list
          if (_banks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
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
          ..._banks.map((bank) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(
                  color: bank['isDefault']
                      ? AppColors.slateBorder
                      : AppColors.hairline,
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
                    child: const Icon(
                      Icons.account_balance,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank['bankName'],
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
                          bank['details'],
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (bank['isDefault']) ...[
                        const OutlinePill('Default'),
                        const SizedBox(height: 4),
                      ],
                      SporveButton(
                        'Remove',
                        onPressed: () {
                          setState(() {
                            _banks.removeWhere((b) => b['id'] == bank['id']);
                          });
                        },
                        variant: SporveButtonVariant.destructive,
                        size: SporveButtonSize.compact,
                        fullWidth: false,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),

          // Add bank account card
          Container(
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
                  'Add bank account',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Account holder name'),
                const SizedBox(height: 6),
                _buildTextInputField(
                  hint: 'Name on account',
                  controller: _nameController,
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Routing number'),
                const SizedBox(height: 6),
                _buildTextInputField(
                  hint: '9-digit routing number',
                  controller: _routingController,
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Account number'),
                const SizedBox(height: 6),
                _buildTextInputField(
                  hint: 'Account number',
                  controller: _accountController,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SporveButton(
                        'Cancel',
                        onPressed: () {
                          _nameController.clear();
                          _routingController.clear();
                          _accountController.clear();
                        },
                        variant: SporveButtonVariant.secondary,
                        onDark: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SporveButton(
                        'Add account',
                        onPressed: () {
                          final account = _accountController.text.trim();
                          if (_nameController.text.trim().isNotEmpty &&
                              _routingController.text.trim().isNotEmpty &&
                              account.length >= 4) {
                            final last4 = account.substring(account.length - 4);
                            setState(() {
                              _banks.add({
                                'id': DateTime.now().millisecondsSinceEpoch,
                                'bankName': 'Linked Bank',
                                'details': 'Checking **** $last4',
                                'isDefault': false,
                              });
                              _nameController.clear();
                              _routingController.clear();
                              _accountController.clear();
                            });
                          } else {
                            Get.snackbar(
                              'Check your details',
                              'Enter a bank name, routing number, and an account number of at least 4 digits.',
                              backgroundColor: AppColors.surface,
                              colorText: AppColors.textPrimary,
                            );
                          }
                        },
                        variant: SporveButtonVariant.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Security Card at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'This is a preview. Bank details entered here are not stored or transmitted.',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: AppTypography.font(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextInputField({
    required String hint,
    required TextEditingController controller,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
        cursorColor: AppColors.slateText,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PAYOUT SCHEDULE
          Text(
            'PAYOUT SCHEDULE',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                _buildScheduleOption('Daily', 'Every business day'),
                const Divider(color: AppColors.hairline, height: 1),
                _buildScheduleOption(
                  'Weekly',
                  'Every Monday for the prior week',
                ),
                const Divider(color: AppColors.hairline, height: 1),
                _buildScheduleOption(
                  'Monthly',
                  '1st of the month for the prior month',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // FEE BREAKDOWN
          Text(
            'FEE BREAKDOWN',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                _buildFeeRow('Sporve commission', kPlatformCommissionLabel),
                const Divider(color: AppColors.hairline, height: 24),
                _buildFeeRow('Stripe processing', kStripeProcessingFeeLabel),
                const Divider(color: AppColors.hairline, height: 24),
                _buildFeeRow('ACH transfer fee', '\$0'),
                const Divider(color: AppColors.hairline, height: 24),
                _buildFeeRow('Payout speed', '1–2 business days'),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildScheduleOption(String title, String subtitle) {
    bool isSelected = _selectedSchedule == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSchedule = title;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              height: 20,
              width: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.slateText
                      : AppColors.textTertiary,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: isSelected
                  ? Container(
                      decoration: const BoxDecoration(
                        color: AppColors.slateText,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
        Text(
          value,
          style: AppTypography.mono(
            size: 13,
            weight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
