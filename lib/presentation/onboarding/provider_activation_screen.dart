import 'dart:io';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

/// Builds an [ImageProvider] for a locally-picked image. `FileImage` throws
/// `UnsupportedError` on Flutter web (no `dart:io` File), so on web we load the
/// picker's blob URL over the network instead.
ImageProvider _localImageProvider(String path) =>
    kIsWeb ? NetworkImage(path) : FileImage(File(path));

class ProviderActivationScreen extends StatelessWidget {
  const ProviderActivationScreen({super.key});

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
                'STEP 6 OF 7',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activation',
              style: AppTypography.font(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header collage
                  Container(
                    height: 140,
                    width: double.infinity,
                    color: AppColors.surface2,
                    child:
                        provider.coverPhotoPath != null &&
                            provider.coverPhotoPath!.isNotEmpty
                        ? Image(
                            image: _localImageProvider(
                              provider.coverPhotoPath!,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.sports_outlined,
                              color: AppColors.slateFg,
                              size: 42,
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (provider.logoPath != null &&
                                provider.logoPath!.isNotEmpty)
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  image: DecorationImage(
                                    image: _localImageProvider(
                                      provider.logoPath!,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            else
                              Text(
                                provider.institutionName.isEmpty
                                    ? 'N'
                                    : provider.institutionName[0],
                                style: AppTypography.font(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.chip,
                                ),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: Text(
                                'DRAFT',
                                style: AppTypography.font(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          provider.institutionName.toUpperCase(),
                          style: AppTypography.font(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                'MODEL',
                                provider.maxAthletes > 1 ? 'Group' : '1-on-1',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoItem(
                                'CAPACITY',
                                '${provider.maxAthletes} Athletes',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                'RATE',
                                [
                                  if (provider.perSessionEnabled)
                                    '\$${provider.perSessionRate.toStringAsFixed(0)}/session (${provider.perSessionDuration}m)',
                                  if (provider.perHourEnabled)
                                    (() {
                                      final double hrs =
                                          provider.perHourDuration / 60.0;
                                      final String hrsText = hrs == hrs.toInt()
                                          ? '${hrs.toInt()}'
                                          : hrs.toStringAsFixed(1);
                                      return '\$${provider.perHourRate.toStringAsFixed(0)}/hour ($hrsText ${hrsText == '1' ? 'hr' : 'hrs'})';
                                    })(),
                                  if (provider.perSeasonEnabled)
                                    '\$${provider.perSeasonRate.toStringAsFixed(0)}/season (${provider.perSeasonDuration} Month${provider.perSeasonDuration > 1 ? 's' : ''})',
                                ].join('\n'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.slateTint,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.tile,
                                  ),
                                  border: Border.all(
                                    color: AppColors.slateBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FREE DEMO',
                                      style: AppTypography.font(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.slateText,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '30 min • In-person',
                                      style: AppTypography.font(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.slateText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'MEDIA',
                              style: AppTypography.font(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildMediaBadge(
                              'Logo',
                              present:
                                  provider.logoPath != null &&
                                  provider.logoPath!.isNotEmpty,
                            ),
                            const SizedBox(width: 8),
                            _buildMediaBadge(
                              'Cover',
                              present:
                                  provider.coverPhotoPath != null &&
                                  provider.coverPhotoPath!.isNotEmpty,
                            ),
                            const SizedBox(width: 8),
                            _buildMediaBadge(
                              provider.galleryPaths.isEmpty
                                  ? 'No photos'
                                  : '${provider.galleryPaths.length} photo${provider.galleryPaths.length == 1 ? '' : 's'}',
                              present: provider.galleryPaths.isNotEmpty,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.slateTint,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.slateBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.slateText,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: AppColors.onSlate,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ready to submit',
                                      style: AppTypography.font(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'We\'ll review your profile before it appears in discovery.',
                                      style: AppTypography.font(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                SporveButton(
                  'Edit',
                  onPressed: () => Get.back(),
                  variant: SporveButtonVariant.tertiary,
                  onDark: true,
                  fullWidth: false,
                ),
                const Spacer(),
                SizedBox(
                  width: 240,
                  child: SporveButton(
                    'Launch my profile',
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success = await provider
                                .submitProviderProfile();
                            if (success) {
                              Get.offAllNamed(AppRoutes.providerTutorial);
                            } else {
                              final errorMsg =
                                  provider.submitError ??
                                  'Failed to launch profile. Please try again.';
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(errorMsg),
                                  backgroundColor: AppColors.negative,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          },
                    loading: provider.isLoading,
                    variant: SporveButtonVariant.primary,
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

  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.font(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.font(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaBadge(String label, {required bool present}) {
    final Color fg = present ? AppColors.slateText : AppColors.textTertiary;
    final Color bg = present ? AppColors.slateTint : AppColors.surface2;
    final Color border = present ? AppColors.slateBorder : AppColors.hairline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(present ? Icons.check : Icons.remove, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.font(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
