import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../controllers/home_controller.dart';
import '../../authentication/controllers/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import '../../widgets/motion_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final userProfile = homeProvider.userProfile;
    // Logged-out browsing (spec §3): a guest sees a "Sign in" prompt instead of
    // account actions. Only a verified user gets Sign out + the account rows.
    final bool isVerified = context.watch<AuthProvider>().isVerified;

    return GradientScaffold(
      body: SafeArea(
        bottom: false,
        child: homeProvider.isLoadingProfile
            ? _buildProfileSkeleton()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP USER CARD
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (userProfile != null)
                                    ? [
                                        (userProfile['firstName'] ?? 'Athlete')
                                            .toString(),
                                        if ((userProfile['lastName'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          '${userProfile['lastName'].toString()[0]}.',
                                      ].join(' ')
                                    : 'Athlete',
                                style: AppTypography.font(
                                  color: AppColors.textPrimary,
                                  fontSize:
                                      28, // §2 Display cap (was 32, auto-clamped)
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Location Badge (grounded from the saved
                                  // address; the fabricated rating + "VERIFIED"
                                  // badges were removed — decision #3).
                                  _buildTopBadge(
                                    (userProfile != null &&
                                            userProfile['address'] is Map &&
                                            ((userProfile['address']
                                                            as Map)['city'] ??
                                                    '')
                                                .toString()
                                                .isNotEmpty)
                                        ? '${(userProfile['address'] as Map)['city'].toString().toUpperCase()}, ${((userProfile['address'] as Map)['state'] ?? '').toString().toUpperCase()}'
                                        : 'LOCATION',
                                  ),
                                ],
                              ),
                            ],
                          ),

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
                            child: ClipOval(
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: SporveImage(
                                  (userProfile != null &&
                                          userProfile['profileImage'] != null)
                                      ? userProfile['profileImage']
                                      : '',
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  fallbackIcon: Icons.person,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. GUEST SIGN-IN PROMPT (logged-out browsing, spec §3).
                    if (!isVerified) _buildGuestPrompt(),

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
                            color: AppColors.blue.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Subtly blended AI glyph background
                            Positioned(
                              right: 24,
                              bottom: -4,
                              child: Opacity(
                                opacity: 0.12,
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.blueText,
                                  size: 84,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const AIBadge(label: 'AI Coach'),
                                  const SizedBox(height: 12),
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
                                    icon: Icons.arrow_forward,
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
                            icon: Icons.edit_outlined,
                            title: 'Edit Profile',
                            subtitle: 'Name, phone, preferred sports',
                            onTap: () => Get.toNamed(AppRoutes.editProfile),
                          ),
                          _buildListOption(
                            icon: Icons.timeline,
                            title: 'Development timeline',
                            subtitle: 'Your child’s session-by-session record',
                            onTap: () => Get.toNamed(AppRoutes.athleteTimeline),
                          ),
                          _buildListOption(
                            icon: Icons.bookmark_border,
                            title: 'Saved Coaches',
                            subtitle: 'Coaches and programs you saved',
                            onTap: () => Get.toNamed(AppRoutes.savedCoaches),
                          ),
                          _buildListOption(
                            icon: Icons.credit_card_outlined,
                            title: 'Payment Methods',
                            subtitle: 'Cards and billing',
                            onTap: () => Get.toNamed(
                              AppRoutes.infoPage,
                              arguments: const {
                                'title': 'Payment Methods',
                                'note':
                                    'Payment details are entered on Stripe’s hosted checkout page.',
                                'sections': [
                                  {
                                    'heading': 'Card details',
                                    'body':
                                        'Sporve stores payment status and processor identifiers, not your full card number.',
                                  },
                                  {
                                    'heading': 'Billing',
                                    'body':
                                        'A booking is confirmed only after Stripe reports payment. Cancelling and refunding are separate operations.',
                                  },
                                ],
                              },
                            ),
                          ),
                          _buildListOption(
                            icon: Icons.notifications_none,
                            title: 'Notifications',
                            subtitle: 'Push, email, and SMS preferences',
                            onTap: () =>
                                Get.toNamed(AppRoutes.notificationSettings),
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
                                        'Sporve uses account, athlete, booking, and communication data to provide the features shown. Production launch requires a published privacy notice covering retention, sharing, and deletion.',
                                  },
                                  {
                                    'heading': 'Child safety',
                                    'body':
                                        'Coaches are gated by verified background checks. A provider that is not verified never appears in your results or the assistant.',
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
                                    'heading': 'How do I book?',
                                    'body':
                                        'Open a listing, pick a session slot and your athlete, then confirm. Your sessions show on Home and the Schedule tab.',
                                  },
                                  {
                                    'heading': 'Refunds & cancellations',
                                    'body':
                                        'Cancelling records the cancellation. Refund eligibility follows the policy copied onto your booking and is confirmed separately by the payment processor.',
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
                                        'By using Sporve you agree to book in good faith and follow each coach’s policies. Sporve is a marketplace connecting families with independent coaches.',
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

                          // Sign Out Button — verified accounts only. A guest
                          // has nothing to sign out of; they see the prompt above.
                          if (isVerified)
                            SporveButton(
                            'Sign out',
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Sign out?',
                                message:
                                    "You'll need to sign in again to access your account.",
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

  /// Guest sign-in prompt (logged-out browsing, spec §3). Shown to a guest in
  /// place of the account actions — browse stays open, auth is invited, never
  /// forced.
  Widget _buildGuestPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in to save coaches, message, and book',
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Browse freely. Create an account when you\'re ready to reach out '
              'to a coach or book a session.',
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SporveButton(
              'Sign in',
              onPressed: () => Get.toNamed(AppRoutes.authEntry),
              variant: SporveButtonVariant.primary,
              icon: Icons.arrow_forward,
            ),
          ],
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
                  Skeleton(height: 30, width: 180),
                  SizedBox(height: 12),
                  Skeleton(height: 22, width: 140),
                ],
              ),
              Skeleton(
                width: 64,
                height: 64,
                radius: BorderRadius.circular(32),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Skeleton(height: 96, radius: BorderRadius.circular(AppRadii.card)),
          const SizedBox(height: 16),
          Skeleton(height: 120, radius: BorderRadius.circular(AppRadii.card)),
          const SizedBox(height: 16),
          Skeleton(height: 320, radius: BorderRadius.circular(AppRadii.card)),
        ],
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
              backgroundColor: AppColors.surface,
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
