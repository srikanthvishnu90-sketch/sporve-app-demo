import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../onboarding/controllers/onboarding_controller.dart';
import 'controllers/auth_provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ambient_surface.dart';
import '../../core/constants/app_assets.dart';
import '../widgets/sporve_button.dart';

/// Apple Sign In is gated OFF until the Apple Developer account + Supabase
/// provider exist (a button that errors is worse than none — audit #14).
const bool kAppleSignInEnabled = false;

Future<void> _openPrivacyPolicy() async {
  final current = Uri.base;
  final uri = current.scheme == 'http' || current.scheme == 'https'
      ? current.resolve('/privacy.html')
      : Uri.parse('https://sporve.vercel.app/privacy.html');
  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}

class AuthEntryScreen extends StatelessWidget {
  const AuthEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isServiceProvider = context
        .watch<OnboardingProvider>()
        .isServiceProvider;
    // Gate the Google button so a redirect-in-flight can't be double-tapped.
    final authLoading = context.watch<AuthProvider>().isLoading;

    // Black canvas (Kalshi model): the mark is a muted grey, wordmark + text
    // stay white for contrast. Concise, single-purpose entry.
    const ink = Colors.white;
    return AmbientSurface(
      baseColor: AppColors.ink,
      focal: const Alignment(0, -0.45),
      radius: 1.1,
      glowOpacity: 0.06,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo rendered as a muted GREY mark on the black canvas
                // (text/buttons stay white).
                Center(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      AppColors.textSecondary,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      AppAssets.appLogo,
                      width: 80,
                      height: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sporve',
                  style: AppTypography.font(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: ink,
                  ),
                ),
                const Spacer(flex: 3),
                // The athlete/provider role choice is PERSISTED (GetStorage in
                // OnboardingProvider), so it survives the Google OAuth redirect
                // round-trip — real Google sign-in is safe to expose here.
                Text(
                  'ACCOUNT ACCESS',
                  style: AppTypography.font(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: ink.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                // REAL Google OAuth (provider provisioned in Supabase; redirect
                // allowlist points at this app). Role choice is persisted above.
                SporveButton(
                  'Continue with Google',
                  leadingWidget: SvgPicture.asset(
                    'assets/icons/google.svg',
                    width: 20,
                    height: 20,
                  ),
                  loading: authLoading,
                  onPressed: authLoading
                      ? null
                      : () => context.read<AuthProvider>().signInWithGoogle(
                          role: isServiceProvider ? 'provider' : 'searcher',
                        ),
                  variant: SporveButtonVariant.white,
                ),
                const SizedBox(height: 14),
                // Apple is hidden until kAppleSignInEnabled (audit #14).
                if (kAppleSignInEnabled) ...[
                  SporveButton(
                    'Continue with Apple',
                    leadingWidget: SvgPicture.asset(
                      'assets/icons/apple.svg',
                      width: 20,
                      height: 20,
                    ),
                    onPressed: () {},
                    variant: SporveButtonVariant.white,
                  ),
                  const SizedBox(height: 14),
                ],
                // Returning users continue to RESTORE (login); brand-new signup
                // stays reachable from the login screen's "create account" link.
                // Provider vs client login honors the persisted role choice.
                SporveButton(
                  'Continue with email',
                  icon: Icons.arrow_forward,
                  onPressed: () => Get.toNamed(
                    isServiceProvider
                        ? AppRoutes.providerLogin
                        : AppRoutes.login,
                  ),
                  variant: SporveButtonVariant.secondary,
                  onDark: true,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTypography.font(
                        color: ink.withValues(alpha: 0.7),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.toNamed(
                        isServiceProvider
                            ? AppRoutes.providerLogin
                            : AppRoutes.login,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Log in',
                        style: AppTypography.font(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'By continuing, you acknowledge Sporve\'s ',
                      style: AppTypography.font(
                        color: ink.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    TextButton(
                      onPressed: _openPrivacyPolicy,
                      style: TextButton.styleFrom(
                        foregroundColor: ink,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Privacy Policy',
                        style: AppTypography.font(
                          color: ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '.',
                      style: AppTypography.font(
                        color: ink.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
