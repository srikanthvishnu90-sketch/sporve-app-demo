import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import 'package:provider/provider.dart';
import '../controllers/provider_controller.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // (Notification/visibility toggle state removed — that UI is commented out and
  // those prefs have no backing column. See report.)
  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isFetching = true;
    });

    try {
      final c = context.read<ProviderController>();
      await c.fetchAccountProfile();
      if (!mounted) return;
      final data = c.accountProfile;
      if (data.isNotEmpty) {
        _firstNameController.text = data['firstName'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        _emailController.text = data['email'] ?? '';
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    // Only the name maps to real columns (profiles). The notification/visibility
    // toggles below have NO column yet — they are intentionally NOT persisted
    // here (flagged for a schema decision) rather than faked into local storage.
    final c = context.read<ProviderController>();
    final ok = await c.saveMyAccount({
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
    });
    if (!mounted) return;
    if (ok) {
      Get.snackbar(
        'Success',
        'Personal profile updated successfully!',
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
          'Personal Profile',
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
                      // Profile Image
                      FadeInDown(
                        duration: const Duration(milliseconds: 500),
                        child: Center(
                          // Avatar upload isn't wired up yet, so no tappable
                          // camera badge is shown (it would be a dead affordance).
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.hairline,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: SizedBox(
                                width: 100,
                                height: 100,
                                child: SporveImage(
                                  '',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  fallbackIcon: Icons.person,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Basic Info Section
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
                                'BASIC INFORMATION',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                validator: (v) => v!.isEmpty
                                    ? 'First name is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                validator: (v) =>
                                    v!.isEmpty ? 'Last name is required' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                readOnly: true,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // TODO(notifications): the push/email notification +
                      // visibility/privacy toggles below (Messages, Bookings,
                      // Promotions, Reminders, SMS Alerts, listingVisibility,
                      // activityStatusEnabled, shareUsageDataEnabled) are HIDDEN —
                      // they had no backing system and persisted nowhere. Restore
                      // this block + its state fields once the push/email backend
                      // and privacy settings exist.
                      /*
                      const SizedBox(height: 20),

                      // Notification Preferences Section
                      FadeInUp(
                        duration: const Duration(milliseconds: 700),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.hairline, width: 1),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NOTIFICATION PREFERENCES',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSwitchRow(
                                title: 'Push Notifications',
                                subtitle: 'Receive alerts on your mobile device',
                                value: _pushEnabled,
                                onChanged: (val) => setState(() => _pushEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'Email Notifications',
                                subtitle: 'Receive summaries and updates via email',
                                value: _emailEnabled,
                                onChanged: (val) => setState(() => _emailEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'In-App Alerts',
                                subtitle: 'Get instant notices within the platform',
                                value: _inAppEnabled,
                                onChanged: (val) => setState(() => _inAppEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'Booking Reminders',
                                subtitle: 'Reminders for upcoming program sessions',
                                value: _bookingReminderEnabled,
                                onChanged: (val) => setState(() => _bookingReminderEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'SMS Alerts',
                                subtitle: 'Get urgent updates via text messaging',
                                value: _smsAlertsEnabled,
                                onChanged: (val) => setState(() => _smsAlertsEnabled = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Privacy Section
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.hairline, width: 1),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRIVACY & DATA',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSwitchRow(
                                title: 'Listing Visibility',
                                subtitle: 'Allow your public pages to be searchable',
                                value: _listingVisibility,
                                onChanged: (val) => setState(() => _listingVisibility = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'Activity Status',
                                subtitle: 'Show when you are active on the platform',
                                value: _activityStatusEnabled,
                                onChanged: (val) => setState(() => _activityStatusEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'Share Usage Data',
                                subtitle: 'Help us improve by sending anonymous usage stats',
                                value: _shareUsageDataEnabled,
                                onChanged: (val) => setState(() => _shareUsageDataEnabled = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                      */
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
    bool readOnly = false,
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
          readOnly: readOnly,
          style: AppTypography.font(
            color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface2,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: BorderSide(
                color: readOnly ? AppColors.hairline : AppColors.slateText,
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
