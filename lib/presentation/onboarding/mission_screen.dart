import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

class MissionScreen extends StatelessWidget {
  MissionScreen({super.key});

  final List<String> missions = [
    'Make the high school team',
    'Get a college scholarship',
    'Play professionally',
    'Get in shape / Have fun',
    'Master fundamentals across the board',
  ];

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
                'STEP 3 OF 4',
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
              'Mission',
              style: AppTypography.font(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'What is your primary goal?',
              style: AppTypography.font(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: missions.length,
                itemBuilder: (context, index) {
                  final mission = missions[index];
                  final isSelected = provider.selectedMission == mission;
                  return GestureDetector(
                    onTap: () => provider.setMission(mission),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.slateTint : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: isSelected ? AppColors.slateBorder : AppColors.hairline),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              mission,
                              style: AppTypography.font(
                                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected) const Icon(Icons.check_circle, color: AppColors.slateText),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SporveButton(
                'Next',
                onPressed: () => Get.toNamed(AppRoutes.almostDone),
                icon: Icons.arrow_forward,
                variant: SporveButtonVariant.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
