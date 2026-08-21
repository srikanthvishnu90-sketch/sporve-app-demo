import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../widgets/sporve_button.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.hairline),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.explore_off_outlined,
                    color: AppColors.slateText,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '404',
                  style: AppTypography.mono(
                    color: AppColors.textPrimary,
                    size: 32,
                    weight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Page Not Found',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The screen or link you\'re looking for does not exist or may have moved.',
                  textAlign: TextAlign.center,
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SporveButton(
                  'Back to Home',
                  onPressed: () => Get.offAllNamed(AppRoutes.mainNav),
                  variant: SporveButtonVariant.primary,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Get.offAllNamed(
                    AppRoutes.mainNav,
                    arguments: {'tab': 1},
                  ),
                  child: Text(
                    'Explore Coaches',
                    style: AppTypography.font(
                      color: AppColors.slateText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
