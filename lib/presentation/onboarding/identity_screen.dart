import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';

import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

import 'package:provider/provider.dart';

class IdentityScreen extends StatelessWidget {
  const IdentityScreen({super.key});

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
                'STEP 2 OF 4',
                style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identity',
              style: AppTypography.font(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
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
                    'FULL NAME',
                    style: AppTypography.font(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => provider.setFullName(v),
                    style: AppTypography.font(color: AppColors.textPrimary),
                    cursorColor: AppColors.slateText,
                    decoration: InputDecoration(
                      hintText: 'e.g. Alex Burton',
                      hintStyle: AppTypography.font(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.tile), borderSide: const BorderSide(color: AppColors.hairline)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.tile), borderSide: const BorderSide(color: AppColors.hairline)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.tile), borderSide: const BorderSide(color: AppColors.slateBorder, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'AGE RANGE',
                    style: AppTypography.font(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildAgeChip(context, '8-10'),
                      _buildAgeChip(context, '11-13'),
                      _buildAgeChip(context, '14-17'),
                      _buildAgeChip(context, '18+'),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
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
                  width: 160,
                  child: SporveButton(
                    'Next',
                    onPressed: () => Get.toNamed(AppRoutes.mission),
                    icon: Icons.arrow_forward,
                    variant: SporveButtonVariant.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  Widget _buildAgeChip(BuildContext context, String label) {
    final provider = context.read<OnboardingProvider>();
    bool isSelected = provider.selectedAgeRange == label;
    return GestureDetector(
      onTap: () => provider.setAgeRange(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slateText : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: isSelected ? AppColors.slateText : AppColors.hairline),
        ),
        child: Text(
          label,
          style: AppTypography.font(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.onSlate : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
