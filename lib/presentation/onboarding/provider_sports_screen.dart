import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/sport_colors.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';
import '../widgets/sport_glyph.dart';

class ProviderSportsScreen extends StatelessWidget {
  const ProviderSportsScreen({super.key});

  final List<Map<String, String>> sports = const [
    {'name': 'BASKETBALL', 'icon': '🏀'},
    {'name': 'SOCCER', 'icon': '⚽'},
    {'name': 'BASEBALL', 'icon': '⚾'},
    {'name': 'TENNIS', 'icon': '🎾'},
    {'name': 'MARTIAL ARTS', 'icon': '🥋'},
    {'name': 'GOLF', 'icon': '⛳'},
    {'name': 'SOFTBALL', 'icon': '🥎'},
    {'name': 'SWIMMING', 'icon': '🏊'},
    {'name': 'FOOTBALL', 'icon': '🏈'},
    {'name': 'HOCKEY', 'icon': '🏒'},
    {'name': 'BOXING', 'icon': '🥊'},
    {'name': 'CRICKET', 'icon': '🏏'},
    {'name': 'TRACK AND FIELD', 'icon': '🏃'},
    {'name': 'CROSS COUNTRY', 'icon': '👟'},
    {'name': 'WATER POLO', 'icon': '🤽'},
    {'name': 'CREW', 'icon': '🚣'},
    {'name': 'WEIGHTLIFTING', 'icon': '🏋️'},
    {'name': 'CHEERLEADING', 'icon': '📣'},
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
                'STEP 2 OF 7',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
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
              'Sports Offered',
              style: AppTypography.font(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Which sports do you offer services for?',
              style: AppTypography.font(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: sports.length,
                  itemBuilder: (context, index) {
                    final sportName = sports[index]['name']!;
                    final sportIcon = sports[index]['icon']!;
                    final isSelected = provider.selectedSports.contains(sportName);
                    return GestureDetector(
                      onTap: () => provider.toggleSport(sportName),
                      child: _buildSportCard(
                        sportName,
                        sportIcon,
                        isSelected,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            SporveButton(
              'Continue',
              onPressed: provider.selectedSports.isNotEmpty
                  ? () => Get.toNamed(AppRoutes.providerCapacity)
                  : null,
              icon: Icons.arrow_forward,
              variant: SporveButtonVariant.primary,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSportCard(String name, String icon, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? SportColors.of(name) : AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(
          color: isSelected ? SportColors.of(name) : AppColors.hairline,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.check_circle, color: SportColors.onColorOf(name), size: 16),
            ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SportGlyph(icon, size: 26, color: isSelected ? SportColors.onColorOf(name) : SportColors.of(name)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    _titleCase(name),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      letterSpacing: 0.2,
                      color: isSelected ? SportColors.onColorOf(name) : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
      .join(' ');
}
