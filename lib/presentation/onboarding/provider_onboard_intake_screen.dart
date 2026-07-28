import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/image_validation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../widgets/common_widgets.dart';
import '../widgets/sporve_button.dart';
import 'controllers/onboard_draft_controller.dart';

/// AI onboarding intake — three OPTIONAL inputs (paste bio, photo, voice
/// transcript) plus a clear "fill in manually instead" skip path. On submit it
/// asks provider-onboard-draft for a draft, then routes to the editable review.
class ProviderOnboardIntakeScreen extends StatefulWidget {
  const ProviderOnboardIntakeScreen({super.key});

  @override
  State<ProviderOnboardIntakeScreen> createState() =>
      _ProviderOnboardIntakeScreenState();
}

class _ProviderOnboardIntakeScreenState
    extends State<ProviderOnboardIntakeScreen> {
  final _bio = TextEditingController();
  final _voice = TextEditingController();

  @override
  void dispose() {
    _bio.dispose();
    _voice.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final c = context.read<OnboardDraftProvider>();
    final XFile? img = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (img == null) return;

    // Validate type + size before base64-encoding into the upload payload.
    final ext = img.name.contains('.')
        ? img.name.split('.').last.toLowerCase()
        : '';
    final mime = img.mimeType ?? '';
    const okExt = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif'};
    if (!(mime.startsWith('image/') || okExt.contains(ext))) {
      if (!mounted) return;
      Get.snackbar(
        'Image',
        'Please choose an image file (JPG, PNG, WEBP, or HEIC).',
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }
    final bytes = await img.readAsBytes();
    if (bytes.lengthInBytes > kMaxImageBytes) {
      if (!mounted) return;
      Get.snackbar(
        'Image',
        'That image is too large. Please pick one under ${kMaxImageBytes ~/ (1024 * 1024)}MB.',
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }
    c.setImage(base64Encode(bytes), img.mimeType ?? 'image/jpeg');
  }

  Future<void> _generate() async {
    final c = context.read<OnboardDraftProvider>();
    c.setBio(_bio.text);
    c.setTranscript(_voice.text);
    final ok = await c.generate();
    if (!mounted) return;
    if (ok) {
      Get.toNamed(AppRoutes.providerOnboardReview);
    } else if (c.error != null) {
      Get.snackbar(
        'Draft',
        c.error!,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OnboardDraftProvider>();
    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.hairline,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Set up your profile',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Drop in whatever you have — we’ll draft it for you. You can edit everything before anything is saved.',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              _sectionLabel('PASTE A BIO'),
              const SizedBox(height: 8),
              _field(
                _bio,
                hint: 'Paste anything about yourself and your coaching…',
                maxLines: 5,
              ),
              const SizedBox(height: 24),

              _sectionLabel('ADD A PHOTO'),
              const SizedBox(height: 8),
              _photoBlock(c),
              const SizedBox(height: 24),

              _sectionLabel('RECORD A VOICE NOTE'),
              const SizedBox(height: 6),
              Text(
                'Tap the mic on your keyboard and just talk — your words become the transcript below.',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              _field(
                _voice,
                hint: 'Your dictated transcript appears here…',
                maxLines: 4,
                prefix: const Icon(
                  Icons.mic_none,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ),
              const SizedBox(height: 28),

              SporveButton(
                'Generate draft',
                onPressed: c.loading ? null : _generate,
                loading: c.loading,
                variant: SporveButtonVariant.primary,
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 12),
              SporveButton(
                'Fill in manually instead',
                onPressed: c.loading
                    ? null
                    : () => Get.toNamed(AppRoutes.providerEditProfile),
                variant: SporveButtonVariant.dark,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Nothing is saved or published until you confirm.',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoBlock(OnboardDraftProvider c) {
    if (c.imageBase64 != null && c.imageBase64!.isNotEmpty) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.tile),
            child: Image.memory(
              base64Decode(c.imageBase64!),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Photo added.',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: c.clearImage,
            child: Text(
              'Remove',
              style: AppTypography.font(
                color: AppColors.destructiveRed,
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: SporveButton(
            'Upload',
            onPressed: () => _pick(ImageSource.gallery),
            variant: SporveButtonVariant.secondary,
            onDark: true,
            icon: Icons.image_outlined,
            size: SporveButtonSize.compact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SporveButton(
            'Take photo',
            onPressed: () => _pick(ImageSource.camera),
            variant: SporveButtonVariant.secondary,
            onDark: true,
            icon: Icons.photo_camera_outlined,
            size: SporveButtonSize.compact,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: AppTypography.font(
      color: AppColors.textTertiary,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
    ),
  );

  Widget _field(
    TextEditingController ctrl, {
    required String hint,
    int maxLines = 1,
    Widget? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix != null) ...[
            Padding(padding: const EdgeInsets.only(top: 14), child: prefix),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: maxLines,
              cursorColor: AppColors.slateText,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
