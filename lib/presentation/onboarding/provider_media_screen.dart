import 'dart:io';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/image_validation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

/// Builds an [ImageProvider] for a locally-picked image. `Image.file`/`FileImage`
/// throw `UnsupportedError` on Flutter web (no `dart:io` File), so on web we load
/// the picker's blob URL over the network instead.
ImageProvider _localImageProvider(String path) =>
    kIsWeb ? NetworkImage(path) : FileImage(File(path));

class ProviderMediaScreen extends StatelessWidget {
  const ProviderMediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final hasMedia =
        (provider.logoPath != null && provider.logoPath!.isNotEmpty) ||
        (provider.coverPhotoPath != null &&
            provider.coverPhotoPath!.isNotEmpty) ||
        provider.galleryPaths.isNotEmpty ||
        (provider.videoUrl != null && provider.videoUrl!.isNotEmpty);

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
                'STEP 5 OF 7',
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
              'Media & Branding',
              style: AppTypography.font(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a logo, photos, and a short intro video so athletes know exactly who they\'re booking with.',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),

            // LOGO
            _buildSection(
              title: 'LOGO',
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      border: Border.all(color: AppColors.hairline),
                      image:
                          provider.logoPath != null &&
                              provider.logoPath!.isNotEmpty
                          ? DecorationImage(
                              image: _localImageProvider(provider.logoPath!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child:
                        provider.logoPath == null || provider.logoPath!.isEmpty
                        ? const Icon(
                            Icons.style,
                            color: AppColors.textSecondary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload your logo',
                          style: AppTypography.font(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'PNG or JPG • Recommended 400x400px',
                          style: AppTypography.font(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SporveButton(
                              provider.logoPath != null &&
                                      provider.logoPath!.isNotEmpty
                                  ? 'Change'
                                  : 'Upload',
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final res = await pickValidatedImage(
                                  ImagePicker(),
                                );
                                if (res.hasError) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res.error!),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                } else if (res.hasImage) {
                                  provider.setLogo(res.path!);
                                }
                              },
                              variant: SporveButtonVariant.secondary,
                              onDark: true,
                              size: SporveButtonSize.compact,
                              fullWidth: false,
                            ),
                            if (provider.logoPath != null &&
                                provider.logoPath!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              SporveButton(
                                'Remove',
                                onPressed: () => provider.setLogo(''),
                                variant: SporveButtonVariant.destructive,
                                size: SporveButtonSize.compact,
                                fullWidth: false,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // COVER PHOTO
            _buildSection(
              title: 'COVER PHOTO',
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final res = await pickValidatedImage(ImagePicker());
                      if (res.hasError) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(res.error!),
                            backgroundColor: AppColors.negative,
                          ),
                        );
                      } else if (res.hasImage) {
                        provider.setCoverPhoto(res.path!);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.hairline),
                        image:
                            provider.coverPhotoPath != null &&
                                provider.coverPhotoPath!.isNotEmpty
                            ? DecorationImage(
                                image: _localImageProvider(
                                  provider.coverPhotoPath!,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child:
                          provider.coverPhotoPath == null ||
                              provider.coverPhotoPath!.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.image,
                                  color: AppColors.textTertiary,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'TAP TO UPLOAD',
                                  style: AppTypography.font(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      provider.setCoverPhoto('');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.negative,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'JPG or PNG • At least 1200x400px • This appears at the top of your listing',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // GALLERY PHOTOS
            _buildSection(
              title: 'GALLERY PHOTOS',
              trailing: '${provider.galleryPaths.length}/4 photos',
              child: Column(
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: List.generate(4, (index) {
                      if (index < provider.galleryPaths.length) {
                        final path = provider.galleryPaths[index];
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.card,
                                ),
                                child: Image(
                                  image: _localImageProvider(path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => provider.removeGalleryPhoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.negative,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return GestureDetector(
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final res = await pickValidatedImage(ImagePicker());
                            if (res.hasError) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(res.error!),
                                  backgroundColor: AppColors.negative,
                                ),
                              );
                            } else if (res.hasImage) {
                              provider.addGalleryPhoto(res.path!);
                            }
                          },
                          child: _buildGalleryPlaceholder(),
                        );
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Show your facility, sessions in action, and team environment. Athletes browse these before booking.',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // INTRO VIDEO
            _buildSection(
              title: 'INTRO VIDEO',
              trailingWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Text(
                  'Optional',
                  style: AppTypography.font(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final video = await picker.pickVideo(
                        source: ImageSource.gallery,
                      );
                      if (video != null) {
                        provider.setVideoUrl(video.path);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.slateTint,
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                            child: const Icon(
                              Icons.movie,
                              color: AppColors.slateText,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.videoUrl != null &&
                                          provider.videoUrl!.isNotEmpty &&
                                          !provider.videoUrl!.startsWith('http')
                                      ? 'Video selected'
                                      : 'Upload a short video',
                                  style: AppTypography.font(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  provider.videoUrl != null &&
                                          provider.videoUrl!.isNotEmpty &&
                                          !provider.videoUrl!.startsWith('http')
                                      ? provider.videoUrl!.split('/').last
                                      : 'MP4 or MOV • Up to 60 seconds • Max 100MB',
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
                          if (provider.videoUrl != null &&
                              provider.videoUrl!.isNotEmpty &&
                              !provider.videoUrl!.startsWith('http'))
                            GestureDetector(
                              onTap: () {
                                provider.setVideoUrl('');
                              },
                              child: const Icon(
                                Icons.delete_outline,
                                color: AppColors.negative,
                              ),
                            )
                          else
                            const Icon(
                              Icons.arrow_forward,
                              color: AppColors.textTertiary,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OR PASTE A LINK',
                    style: AppTypography.font(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => provider.setVideoUrl(v),
                    style: AppTypography.font(color: AppColors.textPrimary),
                    cursorColor: AppColors.slateText,
                    decoration: InputDecoration(
                      hintText: 'https://youtube.com/watch?v=...',
                      hintStyle: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: AppColors.surface2,
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
                        borderSide: const BorderSide(
                          color: AppColors.slateBorder,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Athletes are 4x more likely to book a coach with an intro video. Keep it under 60 seconds.',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
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
                  width: 220,
                  child: SporveButton(
                    hasMedia ? 'Continue' : 'Skip for now',
                    onPressed: () => Get.toNamed(AppRoutes.providerActivation),
                    icon: Icons.arrow_forward,
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

  Widget _buildSection({
    required String title,
    String? trailing,
    Widget? trailingWidget,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.font(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: AppTypography.font(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ?trailingWidget,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildGalleryPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_a_photo,
            color: AppColors.textTertiary,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'ADD PHOTO',
            style: AppTypography.font(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textTertiary,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
