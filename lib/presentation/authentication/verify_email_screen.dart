import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../onboarding/controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';
import 'controllers/auth_provider.dart';

/// Shown after sign-up when the Supabase project has email confirmation ON.
/// Confirmation is link-based (the user taps the link in their inbox), so this
/// is a "check your email" state rather than an OTP entry screen.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final displayEmail = authProvider.registrationEmail ?? 'your email';
    final isServiceProvider =
        Provider.of<OnboardingProvider>(context, listen: false).isServiceProvider;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.mark_email_unread_outlined,
                    color: AppColors.slateText, size: 32),
                const SizedBox(height: 28),
                Text(
                  'Check your email',
                  style: AppTypography.font(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: AppTypography.font(
                        color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                    children: [
                      const TextSpan(text: 'We sent a confirmation link to '),
                      TextSpan(
                        text: displayEmail,
                        style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text:
                            '. Tap it to activate your account, then come back and log in.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(top: BorderSide(color: AppColors.hairline)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.card),
                  topRight: Radius.circular(AppRadii.card),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  SporveButton(
                    'Back to log in',
                    onPressed: () => Get.offAllNamed(
                        isServiceProvider ? AppRoutes.providerLogin : AppRoutes.login),
                    variant: SporveButtonVariant.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Didn't get the email? Check your spam folder.",
                    textAlign: TextAlign.center,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
