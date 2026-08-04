import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../authentication/controllers/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import '../../widgets/motion_widgets.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  bool _isLoading = true;
  String _displayName = 'Loading...';
  String _verificationStatus = 'pending';
  String _city = '';
  String _state = '';
  String _logoUrl = '';

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final c = context.read<ProviderController>();
      await Future.wait([c.fetchAccountProfile(), c.fetchProviderProfile()]);
      if (!mounted) return;
      final userData = c.accountProfile;
      final providerData = c.providerProfile;

      if (userData.isNotEmpty) {
        final fName = userData['firstName'] ?? '';
        final lName = userData['lastName'] ?? '';
        setState(() {
          _displayName = '$fName $lName'.trim();
          if (_displayName.isEmpty) _displayName = 'Provider Profile';
        });
      }

      if (providerData.isNotEmpty) {
        setState(() {
          // The badge reflects the real trust signal (verification_status),
          // which is admin/service-role only — NEVER `status`. A freshly
          // onboarded provider is honestly 'unverified' until an admin verifies
          // them, rather than showing 'approved' as if it were a trust badge.
          _verificationStatus =
              providerData['verificationStatus'] ?? 'unverified';
          _logoUrl = providerData['logo'] ?? userData['profileImage'] ?? '';

          final address = providerData['address'];
          if (address != null) {
            _city = address['city'] ?? '';
            _state = address['state'] ?? '';
          } else {
            final locationStr = providerData['location'] ?? '';
            final parts = locationStr.split(',');
            if (parts.length == 2) {
              _city = parts[0].trim();
              _state = parts[1].trim();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getVerificationColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return AppColors.successGreen;
      case 'pending':
        return AppColors.warmAccent;
      case 'rejected':
        return AppColors.negative;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData _getVerificationIcon(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Icons.check;
      case 'pending':
        return Icons.hourglass_empty;
      case 'rejected':
        return Icons.close;
      default:
        return Icons.info_outline;
    }
  }

  /// Real profile completeness — fraction of the 5 key fields that are filled.
  double _profileStrength(Map<String, dynamic> p) {
    var score = 0;
    if ((p['businessName'] ?? '').toString().trim().isNotEmpty) score++;
    if ((p['bio'] ?? '').toString().trim().isNotEmpty) score++;
    if ((p['sports'] is List) && (p['sports'] as List).isNotEmpty) score++;
    if ((p['location'] ?? '').toString().trim().isNotEmpty) score++;
    if (p['verificationStatus'] == 'verified' ||
        p['stripeChargesEnabled'] == true) {
      score++;
    }
    return score / 5;
  }

  @override
  Widget build(BuildContext context) {
    final strength = _profileStrength(
      context.watch<ProviderController>().providerProfile,
    );
    final strengthPct = (strength * 100).round();
    return GradientScaffold(
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? _buildProfileSkeleton()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP USER CARD (USER DISPLAY NAME AND PHOTO)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (Name and Badges)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName,
                                  style: AppTypography.font(
                                    color: AppColors.textPrimary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      // Rating Badge — grounded: no reviews table is
                                      // loaded here, so never fabricate "★ 4.8".
                                      _buildTopBadge('New'),
                                      const SizedBox(width: 6),
                                      // Dynamic Verification Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.chip,
                                          ),
                                          border: Border.all(
                                            color: _getVerificationColor(
                                              _verificationStatus,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getVerificationIcon(
                                                _verificationStatus,
                                              ),
                                              color: _getVerificationColor(
                                                _verificationStatus,
                                              ),
                                              size: 10,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _verificationStatus.toUpperCase(),
                                              style: AppTypography.font(
                                                color: _getVerificationColor(
                                                  _verificationStatus,
                                                ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Location Badge
                                      _buildTopBadge(
                                        '${_city.toUpperCase()}, ${_state.toUpperCase()}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Right Avatar Photo
                          Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.hairline,
                                width: 2,
                              ),
                            ),
                            child: SporveImage(
                              _logoUrl.isNotEmpty ? _logoUrl : '',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              radius: 32,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. PROFILE STRENGTH CARD (72%)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(
                            color: AppColors.hairlineSoft,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Profile strength',
                                  style: AppTypography.font(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '$strengthPct%',
                                  style: AppTypography.font(
                                    color: AppColors.slateText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Custom Linear Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadii.chip,
                              ),
                              child: LinearProgressIndicator(
                                value: strength,
                                backgroundColor: AppColors.surface2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.slateText,
                                ),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RichText(
                              text: TextSpan(
                                style: AppTypography.font(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Add a profile photo to get ',
                                  ),
                                  TextSpan(
                                    text: '3x more bookings',
                                    style: AppTypography.font(
                                      color: AppColors.slateText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. AI COACH PURPLE BANNER
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.blueTint,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(
                            color: AppColors.hairline,
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Subtly blended AI glyph background with low opacity
                            Positioned(
                              right: 24,
                              bottom: -4,
                              child: Opacity(
                                opacity: 0.12,
                                child: Icon(
                                  Icons.psychology_outlined,
                                  size: 84,
                                  color: AppColors.blueText,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Coach',
                                    style: AppTypography.font(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'COACH DISCOVERY AND BOOKING HELP',
                                    style: AppTypography.font(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  // ASK A QUESTION Button
                                  SporveButton(
                                    'Ask a question',
                                    onPressed: () =>
                                        Get.toNamed(AppRoutes.aiAssistant),
                                    variant: SporveButtonVariant.primary,
                                    size: SporveButtonSize.compact,
                                    fullWidth: false,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 4. MAIN LIST OPTIONS (ACCURATE FLOATING WHITE CARD MATCHING FIGMA)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 12,
                        bottom: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        children: [
                          _buildListOption(
                            icon: Icons.person_outline,
                            title: 'Personal Profile',
                            subtitle: 'Name, photo, email, phone number',
                            onTap: () =>
                                Get.toNamed(AppRoutes.providerPersonalProfile),
                          ),
                          _buildListOption(
                            icon: Icons.storefront_outlined,
                            title: 'Service Profile',
                            subtitle:
                                'Business details, sports, pricing, branding',
                            onTap: () =>
                                Get.toNamed(AppRoutes.providerServiceProfile),
                          ),
                          _buildListOption(
                            icon: Icons.policy_outlined,
                            title: 'My Policies',
                            subtitle:
                                'Cancellation, what to bring, FAQ — what the assistant can cite',
                            onTap: () =>
                                Get.toNamed(AppRoutes.providerPolicies),
                          ),
                          _buildListOption(
                            icon: Icons.people_outline,
                            title: 'Roster Management',
                            subtitle: 'Athletes, availability, payments',
                            onTap: () => Get.toNamed(AppRoutes.providerRoster),
                          ),
                          _buildListOption(
                            icon: Icons.business_center_outlined,
                            title: 'Earnings & Payouts',
                            subtitle: 'Revenue, invoices, bank transfers',
                            onTap: () =>
                                Get.toNamed(AppRoutes.providerFinances),
                          ),
                          _buildListOption(
                            icon: Icons.credit_card_outlined,
                            title: 'Payment Methods',
                            subtitle: 'Cards and billing',
                            onTap: () =>
                                Get.toNamed(AppRoutes.providerPayoutsPayments),
                          ),
                          _buildListOption(
                            icon: Icons.notifications_none,
                            title: 'Notifications',
                            subtitle: 'Push, email, and SMS preferences',
                            onTap: () =>
                                Get.toNamed(AppRoutes.notificationSettings),
                          ),
                          _buildListOption(
                            icon: Icons.auto_awesome,
                            title: 'Automated messages',
                            subtitle: 'Off / draft / auto per message type',
                            onTap: () =>
                                Get.toNamed(AppRoutes.automatedMessages),
                          ),
                          _buildListOption(
                            icon: Icons.mark_email_unread_outlined,
                            title: 'Approval queue',
                            subtitle: 'Review and send drafted messages',
                            onTap: () =>
                                Get.toNamed(AppRoutes.lifecycleApprovals),
                          ),
                          _buildListOption(
                            icon: Icons.shield_outlined,
                            title: 'Privacy & Security',
                            subtitle: 'Visibility, data, and password',
                            onTap: () => Get.toNamed(
                              AppRoutes.infoPage,
                              arguments: const {
                                'title': 'Privacy & Security',
                                'sections': [
                                  {
                                    'heading': 'Your data',
                                    'body':
                                        'Sporve uses your account, roster, booking, and communication data to run your program. Production launch requires a published privacy notice covering retention, sharing, and deletion.',
                                  },
                                  {
                                    'heading': 'Athlete safety',
                                    'body':
                                        'Providers are gated by verified background checks. Keep your verification current so your listings stay discoverable.',
                                  },
                                  {
                                    'heading': 'Password',
                                    'body':
                                        'You can reset your password from the sign-in screen. We recommend a unique passphrase.',
                                  },
                                ],
                              },
                            ),
                          ),
                          _buildListOption(
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            subtitle: 'FAQs, contact us, report a problem',
                            onTap: () => Get.toNamed(
                              AppRoutes.infoPage,
                              arguments: const {
                                'title': 'Help & Support',
                                'sections': [
                                  {
                                    'heading': 'Creating a listing',
                                    'body':
                                        'Tap "Create new listing" on your dashboard, add your program details and pricing, then publish. Live listings appear under the Listings tab.',
                                  },
                                  {
                                    'heading': 'Payouts',
                                    'body':
                                        'Connect a Stripe account from the dashboard to receive payouts. A booking is confirmed only after the payment processor reports payment.',
                                  },
                                  {
                                    'heading': 'Contact us',
                                    'body':
                                        'Email support@sporve.com. Response times are not guaranteed.',
                                  },
                                ],
                              },
                            ),
                          ),
                          _buildListOption(
                            icon: Icons.gavel_outlined,
                            title: 'Legal',
                            subtitle: 'Terms, privacy policy, licenses',
                            onTap: () => Get.toNamed(
                              AppRoutes.infoPage,
                              arguments: const {
                                'title': 'Legal',
                                'sections': [
                                  {
                                    'heading': 'Terms of Service',
                                    'body':
                                        'By using Sporve you agree to honor the bookings and policies attached to your listings. Sporve is a marketplace connecting families with independent coaches and academies.',
                                  },
                                  {
                                    'heading': 'Privacy Policy',
                                    'body':
                                        'We process personal data to provide the service and protect athletes. You may request deletion of your account at any time.',
                                  },
                                  {
                                    'heading': 'Licenses',
                                    'body':
                                        'Sporve is built with open-source software. Component licenses are available on request.',
                                  },
                                ],
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Sign Out Row
                          SporveButton(
                            'Sign out',
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Sign out?',
                                message:
                                    "You'll need to sign in again to manage your program.",
                                confirmLabel: 'Sign out',
                                destructive: true,
                              );
                              if (!ok || !context.mounted) return;
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              await authProvider.logout();
                              Get.offAllNamed(AppRoutes.authEntry);
                            },
                            variant: SporveButtonVariant.destructive,
                            icon: Icons.exit_to_app,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 100,
                    ), // spacing for bottom navigation bar
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTopBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(
        text,
        style: AppTypography.font(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// First-load skeleton (instead of a bare centered spinner).
  Widget _buildProfileSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(height: 28, width: 180),
                  SizedBox(height: 12),
                  Skeleton(height: 18, width: 120),
                ],
              ),
              Skeleton(
                width: 72,
                height: 72,
                radius: BorderRadius.circular(36),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Skeleton(height: 110, radius: BorderRadius.circular(AppRadii.card)),
          const SizedBox(height: 16),
          Skeleton(height: 96, radius: BorderRadius.circular(AppRadii.card)),
          const SizedBox(height: 16),
          Skeleton(height: 300, radius: BorderRadius.circular(AppRadii.card)),
        ],
      ),
    );
  }

  Widget _buildListOption({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            Get.snackbar(
              title,
              'Opening $title settings...',
              backgroundColor: AppColors.surface2,
              colorText: AppColors.textPrimary,
            );
          },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
