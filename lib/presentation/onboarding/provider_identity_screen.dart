import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

class ProviderIdentityScreen extends StatefulWidget {
  const ProviderIdentityScreen({super.key});

  @override
  State<ProviderIdentityScreen> createState() => _ProviderIdentityScreenState();
}

class _ProviderIdentityScreenState extends State<ProviderIdentityScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OnboardingProvider>();
      _nameController.text = provider.institutionName;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                'STEP 1 OF 7',
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
            const SizedBox(height: 20),
            Text(
              'Scale your impact today',
              style: AppTypography.display.copyWith(
                fontSize: 26,
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
                    'INSTITUTION NAME',
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    onChanged: (v) => provider.setInstitutionName(v),
                    cursorColor: AppColors.slateText,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Academy One',
                      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
              ),
            ),
            const SizedBox(height: 32),
            SporveButton(
              'Continue',
              onPressed: provider.institutionName.isNotEmpty
                  ? () => Get.toNamed(AppRoutes.providerSports)
                  : null,
              variant: SporveButtonVariant.primary,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
