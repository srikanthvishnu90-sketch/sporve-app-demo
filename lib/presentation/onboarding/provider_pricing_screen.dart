import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

class ProviderPricingScreen extends StatefulWidget {
  const ProviderPricingScreen({super.key});

  @override
  State<ProviderPricingScreen> createState() => _ProviderPricingScreenState();
}

class _ProviderPricingScreenState extends State<ProviderPricingScreen> {
  late TextEditingController _sessionRateController;
  late TextEditingController _hourRateController;
  late TextEditingController _seasonRateController;
  late TextEditingController _customHoursController;
  bool _isCustomHour = false;

  int _parseHoursToIntMinutes(String text) {
    final cleanText = text.replaceAll(RegExp(r'[^0-9\.]'), '').trim();
    final val = double.tryParse(cleanText) ?? 1.0;
    return (val * 60).round();
  }

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<OnboardingProvider>(context, listen: false);
    _sessionRateController = TextEditingController(
      text: provider.perSessionRate > 0 ? provider.perSessionRate.toStringAsFixed(0) : '',
    );
    _hourRateController = TextEditingController(
      text: provider.perHourRate > 0 ? provider.perHourRate.toStringAsFixed(0) : '',
    );
    _seasonRateController = TextEditingController(
      text: provider.perSeasonRate > 0 ? provider.perSeasonRate.toStringAsFixed(0) : '',
    );

    final initialHours = provider.perHourDuration ~/ 60;
    _isCustomHour = ![1, 2, 3].contains(initialHours);
    _customHoursController = TextEditingController(
      text: _isCustomHour && initialHours > 0 ? initialHours.toString() : '',
    );
  }

  @override
  void dispose() {
    _sessionRateController.dispose();
    _hourRateController.dispose();
    _seasonRateController.dispose();
    _customHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

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
              child: Text(
                'STEP 4 OF 7',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing',
              style: AppTypography.display.copyWith(
                fontSize: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set your rates and let athletes know if you offer a free first session.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW DO YOU CHARGE?',
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. Per Session Pricing
                  _buildSessionPricingCard(context, provider),

                  const Divider(height: 48, color: AppColors.hairline, thickness: 1),

                  // 2. Per Hour Pricing
                  _buildHourPricingCard(context, provider),

                  const Divider(height: 48, color: AppColors.hairline, thickness: 1),
                  
                  // 3. Per Season Pricing
                  _buildSeasonPricingCard(context, provider),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                SporveButton(
                  'Back',
                  onPressed: () => Get.back(),
                  variant: SporveButtonVariant.tertiary,
                  onDark: true,
                  fullWidth: false,
                ),
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: SporveButton(
                    'Next',
                    icon: Icons.arrow_forward,
                    variant: SporveButtonVariant.primary,
                    onPressed: () {
                      if (!provider.perSessionEnabled &&
                          !provider.perHourEnabled &&
                          !provider.perSeasonEnabled) {
                        Get.snackbar(
                          'Pricing Required',
                          'Please enable at least one pricing option to continue.',
                          backgroundColor: AppColors.negative,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      if (provider.perSessionEnabled && provider.perSessionRate <= 0.0) {
                        Get.snackbar(
                          'Rate Required',
                          'Please set a rate for Per session.',
                          backgroundColor: AppColors.negative,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      if (provider.perHourEnabled && provider.perHourRate <= 0.0) {
                        Get.snackbar(
                          'Rate Required',
                          'Please set a rate for Per hour.',
                          backgroundColor: AppColors.negative,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      if (provider.perSeasonEnabled && provider.perSeasonRate <= 0.0) {
                        Get.snackbar(
                          'Rate Required',
                          'Please set a rate for Per season.',
                          backgroundColor: AppColors.negative,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      Get.toNamed(AppRoutes.providerMedia);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionPricingCard(BuildContext context, OnboardingProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Per session',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'One-time fee',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Switch.adaptive(
              value: provider.perSessionEnabled,
              activeTrackColor: AppColors.slateText,
              onChanged: (val) => provider.setPerSessionEnabled(val),
            ),
          ],
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          firstChild: const SizedBox(height: 0),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'DURATION',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDurationChip(context, 15, provider.perSessionDuration, (val) => provider.setPerSessionDuration(val))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDurationChip(context, 30, provider.perSessionDuration, (val) => provider.setPerSessionDuration(val))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDurationChip(context, 45, provider.perSessionDuration, (val) => provider.setPerSessionDuration(val))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDurationChip(context, 60, provider.perSessionDuration, (val) => provider.setPerSessionDuration(val))),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'YOUR RATE (PER SESSION)',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildRateInput(
                controller: _sessionRateController,
                currentRate: provider.perSessionRate,
                onRateChange: (val) => provider.setPerSessionRate(val),
                labelSuffix: 'session',
              ),
            ],
          ),
          crossFadeState: provider.perSessionEnabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        ),
      ],
    );
  }

  Widget _buildHourPricingCard(BuildContext context, OnboardingProvider provider) {
    final currentHours = provider.perHourDuration ~/ 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Per hour',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Hourly rate',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Switch.adaptive(
              value: provider.perHourEnabled,
              activeTrackColor: AppColors.slateText,
              onChanged: (val) => provider.setPerHourEnabled(val),
            ),
          ],
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          firstChild: const SizedBox(height: 0),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'DURATION',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildHourChip(
                      '1 hr',
                      currentHours == 1 && !_isCustomHour,
                      () {
                        setState(() {
                          _isCustomHour = false;
                          provider.setPerHourDuration(60);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHourChip(
                      '2 hrs',
                      currentHours == 2 && !_isCustomHour,
                      () {
                        setState(() {
                          _isCustomHour = false;
                          provider.setPerHourDuration(120);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHourChip(
                      '3 hrs',
                      currentHours == 3 && !_isCustomHour,
                      () {
                        setState(() {
                          _isCustomHour = false;
                          provider.setPerHourDuration(180);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHourChip(
                      'Custom',
                      _isCustomHour,
                      () {
                        setState(() {
                          _isCustomHour = true;
                          final minutes = _parseHoursToIntMinutes(_customHoursController.text);
                          provider.setPerHourDuration(minutes);
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_isCustomHour) ...[
                const SizedBox(height: 12),
                Text(
                  'ENTER HOURS',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customHoursController,
                  onChanged: (v) {
                    final minutes = _parseHoursToIntMinutes(v);
                    provider.setPerHourDuration(minutes);
                  },
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  cursorColor: AppColors.slateText,
                  decoration: InputDecoration(
                    hintText: 'e.g. 5 hours',
                    hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'YOUR RATE (PER HOUR)',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildRateInput(
                controller: _hourRateController,
                currentRate: provider.perHourRate,
                onRateChange: (val) => provider.setPerHourRate(val),
                labelSuffix: 'hour',
              ),
            ],
          ),
          crossFadeState: provider.perHourEnabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        ),
      ],
    );
  }

  Widget _buildSeasonPricingCard(BuildContext context, OnboardingProvider provider) {
    final dropdownValue = [1, 2, 3, 4, 6, 8, 12].contains(provider.perSeasonDuration) 
        ? provider.perSeasonDuration 
        : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Per season',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Program fee',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Switch.adaptive(
              value: provider.perSeasonEnabled,
              activeTrackColor: AppColors.slateText,
              onChanged: (val) => provider.setPerSeasonEnabled(val),
            ),
          ],
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          firstChild: const SizedBox(height: 0),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'DURATION',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: dropdownValue,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 24),
                    dropdownColor: AppColors.surface2,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    onChanged: (val) {
                      if (val != null) {
                        provider.setPerSeasonDuration(val);
                      }
                    },
                    items: const [
                      DropdownMenuItem<int>(
                        value: 1,
                        child: Text('1 Month'),
                      ),
                      DropdownMenuItem<int>(
                        value: 2,
                        child: Text('2 Months'),
                      ),
                      DropdownMenuItem<int>(
                        value: 3,
                        child: Text('3 Months'),
                      ),
                      DropdownMenuItem<int>(
                        value: 4,
                        child: Text('4 Months'),
                      ),
                      DropdownMenuItem<int>(
                        value: 6,
                        child: Text('6 Months'),
                      ),
                      DropdownMenuItem<int>(
                        value: 8,
                        child: Text('8 Months'),
                      ),
                      DropdownMenuItem<int>(
                        value: 12,
                        child: Text('12 Months (1 Year)'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'YOUR RATE (PER SEASON)',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildRateInput(
                controller: _seasonRateController,
                currentRate: provider.perSeasonRate,
                onRateChange: (val) => provider.setPerSeasonRate(val),
                labelSuffix: 'season',
              ),
            ],
          ),
          crossFadeState: provider.perSeasonEnabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        ),
      ],
    );
  }

  Widget _buildHourChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? AppColors.slateText : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: isActive ? AppColors.slateText : AppColors.hairline),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive ? AppColors.onSlate : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(BuildContext context, int minutes, int currentDuration, ValueChanged<int> onTap) {
    bool isSelected = currentDuration == minutes;
    return GestureDetector(
      onTap: () => onTap(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slateText : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: isSelected ? AppColors.slateText : AppColors.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$minutes',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.onSlate : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'min',
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: isSelected ? AppColors.onSlate : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateInput({
    required TextEditingController controller,
    required double currentRate,
    required ValueChanged<double> onRateChange,
    required String labelSuffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Text(
                '\$',
                style: AppTypography.heading.copyWith(
                  fontSize: 24,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (v) => onRateChange(double.tryParse(v) ?? 0.0),
                  keyboardType: TextInputType.number,
                  cursorColor: AppColors.slateText,
                  style: AppTypography.display.copyWith(
                    fontSize: 32,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppTypography.display.copyWith(fontSize: 32, color: AppColors.textTertiary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(
                'USD',
                style: AppTypography.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.check, color: AppColors.slateText, size: 16),
            const SizedBox(width: 8),
            Text(
              'Athletes will see \$${(currentRate * 1.05).toStringAsFixed(0)}/$labelSuffix',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slateText,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
