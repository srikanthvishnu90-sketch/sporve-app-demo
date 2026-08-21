import 'dart:io';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/image_validation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import 'package:provider/provider.dart';
import '../controllers/provider_controller.dart';

class ServiceProfileScreen extends StatefulWidget {
  const ServiceProfileScreen({super.key});

  @override
  State<ServiceProfileScreen> createState() => _ServiceProfileScreenState();
}

class _ServiceProfileScreenState extends State<ServiceProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _businessNameController = TextEditingController();

  // Selected Sports list
  final List<String> _availableSports = [
    'Soccer',
    'Basketball',
    'Tennis',
    'Football',
    'Swimming',
    'Martial Arts',
    'Baseball',
  ];
  final List<String> _selectedSports = [];

  // NOTE: provider-level pricing (per session/hour/season) was REMOVED — pricing
  // lives on each program (programs.price), the single source of truth.

  bool _isLoading = false;
  bool _isFetching = true;

  // Selected files/URLs
  String? _logoUrl;
  String? _coverUrl;
  String? _localLogoPath;
  String? _localCoverPath;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isFetching = true;
    });

    final c = context.read<ProviderController>();
    try {
      await c.fetchProviderProfile();
      if (!mounted) return;
      final data = c.providerProfile;
      if (data.isNotEmpty) {
        _businessNameController.text = data['businessName'] ?? '';

        if (data['sports'] != null) {
          _selectedSports.clear();
          for (var sport in data['sports']) {
            _selectedSports.add(sport.toString());
          }
        }

        _logoUrl = data['logo'];
        _coverUrl = data['coverImage'];
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        backgroundColor: AppColors.negative,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSports.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select at least one sport.',
        backgroundColor: AppColors.negative,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final Map<String, dynamic> body = {
      'businessName': _businessNameController.text.trim(),
      'supportedSports': _selectedSports,
    };

    // Only business_name + sports map to real columns. pricingOptions, logo and
    // coverImage have NO provider column (pricing is per-program; logo/cover need
    // Storage) — intentionally NOT persisted here (flagged), never faked.
    final c = context.read<ProviderController>();
    final ok = await c.saveMyProvider({
      'businessName': body['businessName'],
      'sports': _selectedSports.toList(),
    });
    if (!mounted) return;
    if (ok) {
      Get.snackbar(
        'Success',
        'Service profile updated successfully!',
        backgroundColor: AppColors.slateText,
        colorText: AppColors.onSlate,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } else {
      Get.snackbar(
        'Error',
        c.profileError ?? 'Could not save. Please try again.',
        backgroundColor: AppColors.negative,
        colorText: AppColors.textPrimary,
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Service Profile',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isFetching
            ? const Center(child: SkeletonList())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Business Name Card
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(
                              color: AppColors.hairlineSoft,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BUSINESS DETAILS',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _businessNameController,
                                label: 'Business / Academy Name',
                                validator: (v) => v!.isEmpty
                                    ? 'Business name is required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Supported Sports Card
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(
                              color: AppColors.hairlineSoft,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SUPPORTED SPORTS',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _availableSports.map((sport) {
                                  final isSelected = _selectedSports.any(
                                    (s) =>
                                        s.toUpperCase() == sport.toUpperCase(),
                                  );
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedSports.removeWhere(
                                            (s) =>
                                                s.toUpperCase() ==
                                                sport.toUpperCase(),
                                          );
                                        } else {
                                          _selectedSports.add(sport);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.slateTint
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.tile,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.slateBorder
                                              : AppColors.hairline,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            SportColors.iconOf(sport),
                                            size: 16,
                                            color: isSelected
                                                ? AppColors.slateText
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            sport,
                                            style: AppTypography.font(
                                              color: isSelected
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary,
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Logo and Cover Photo Selection
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(
                              color: AppColors.hairlineSoft,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MEDIA & BRANDING',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Logo Row
                              Row(
                                children: [
                                  Container(
                                    height: 64,
                                    width: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface2,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.tile,
                                      ),
                                      border: Border.all(
                                        color: AppColors.hairline,
                                      ),
                                    ),
                                    child: _localLogoPath != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              AppRadii.tile,
                                            ),
                                            child: Image.file(
                                              File(_localLogoPath!),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : (_logoUrl != null
                                              ? SporveImage(
                                                  _logoUrl,
                                                  width: 64,
                                                  height: 64,
                                                  fit: BoxFit.cover,
                                                  radius: AppRadii.tile,
                                                  fallbackIcon: Icons.business,
                                                )
                                              : const Icon(
                                                  Icons.business,
                                                  color:
                                                      AppColors.textSecondary,
                                                )),
                                  ),
                                  const SizedBox(width: 16),
                                  SporveButton(
                                    'Change logo',
                                    onPressed: () async {
                                      final res = await pickValidatedImage(
                                        ImagePicker(),
                                      );
                                      if (res.hasError) {
                                        Get.snackbar(
                                          'Image',
                                          res.error!,
                                          backgroundColor: AppColors.negative,
                                          colorText: Colors.white,
                                        );
                                      } else if (res.hasImage) {
                                        setState(() {
                                          _localLogoPath = res.path!;
                                        });
                                      }
                                    },
                                    variant: SporveButtonVariant.secondary,
                                    onDark: true,
                                    size: SporveButtonSize.compact,
                                    fullWidth: false,
                                  ),
                                ],
                              ),
                              const Divider(
                                color: AppColors.hairline,
                                height: 32,
                              ),
                              // Cover Photo Row
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'COVER PHOTO',
                                    style: AppTypography.font(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface2,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.tile,
                                      ),
                                      border: Border.all(
                                        color: AppColors.hairline,
                                      ),
                                    ),
                                    child: _localCoverPath != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              AppRadii.tile,
                                            ),
                                            child: Image.file(
                                              File(_localCoverPath!),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : (_coverUrl != null
                                              ? SporveImage(
                                                  _coverUrl,
                                                  width: double.infinity,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                  radius: AppRadii.tile,
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    Icons.image,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                )),
                                  ),
                                  const SizedBox(height: 12),
                                  SporveButton(
                                    'Change cover photo',
                                    onPressed: () async {
                                      final picker = ImagePicker();
                                      final image = await picker.pickImage(
                                        source: ImageSource.gallery,
                                      );
                                      if (image != null) {
                                        setState(() {
                                          _localCoverPath = image.path;
                                        });
                                      }
                                    },
                                    variant: SporveButtonVariant.secondary,
                                    onDark: true,
                                    size: SporveButtonSize.compact,
                                    fullWidth: false,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      FadeInUp(
                        duration: const Duration(milliseconds: 900),
                        child: SporveButton(
                          'Save changes',
                          onPressed: _isLoading ? null : _saveProfile,
                          variant: SporveButtonVariant.primary,
                          loading: _isLoading,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface2,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(
                color: AppColors.slateText,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.negative),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(
                color: AppColors.negative,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
