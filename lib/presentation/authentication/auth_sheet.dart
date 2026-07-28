import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../widgets/sporve_button.dart';
import 'controllers/auth_provider.dart';

/// Airbnb-style auth popup. The app is fully browsable as a guest; this sheet
/// only appears to ASK you to sign in / create an account — never a blocking
/// screen. Dismiss by swiping down, tapping the X, or tapping outside.
/// Wired from [AuthProvider.requireAuth] (booking, save, plan, …) and shown
/// once on entry via [AuthProvider.maybeShowEntryPrompt].
void showSporveAuthSheet() {
  if (Get.isBottomSheetOpen ?? false) return; // never stack two
  Get.bottomSheet(
    const _SporveAuthSheet(),
    isScrollControlled: true,
    isDismissible: true, // tap-outside closes
    enableDrag: true, // swipe-down closes
    backgroundColor: Colors.transparent,
  );
}

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

class _SporveAuthSheet extends StatelessWidget {
  const _SporveAuthSheet();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final screenH = MediaQuery.of(context).size.height;
    // A tall, vertical auth screen — the full-entry look, presented as a
    // dismissible sheet. Black canvas, grey mark; buttons + policy anchored low.
    return Container(
      height: screenH * 0.86,
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottomInset),
      child: Column(
        children: [
          // Grab handle — signals swipe-to-dismiss.
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          // Explicit X — the second dismiss affordance.
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              splashRadius: 20,
              tooltip: 'Close',
            ),
          ),
          const Spacer(flex: 2),
          // Grey Sporve mark + wordmark (matches the full auth entry screen).
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              AppColors.textSecondary,
              BlendMode.srcIn,
            ),
            child: Image.asset(AppAssets.appLogo, width: 72, height: 72),
          ),
          const SizedBox(height: 18),
          Text(
            'Sporve',
            style: AppTypography.font(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Log in or sign up',
            textAlign: TextAlign.center,
            style: AppTypography.font(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book sessions, message coaches, and save your favorites.',
            textAlign: TextAlign.center,
            style: AppTypography.font(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(flex: 3),
          SporveButton(
            'Continue with Google',
            leadingWidget: SvgPicture.asset(
              'assets/icons/google.svg',
              width: 20,
              height: 20,
            ),
            onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
            variant: SporveButtonVariant.white,
          ),
          const SizedBox(height: 12),
          SporveButton(
            'Continue with email',
            icon: Icons.arrow_forward,
            onPressed: () {
              Get.back(); // close the sheet, then open the email flow
              Get.toNamed(AppRoutes.onboarding);
            },
            variant: SporveButtonVariant.secondary,
            onDark: true,
          ),
          const SizedBox(height: 16),
          Text(
            'You can keep browsing without an account.',
            textAlign: TextAlign.center,
            style: AppTypography.font(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          // Privacy policy — mirrors the full auth entry screen.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'By continuing, you acknowledge Sporve\'s ',
                style: AppTypography.font(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              GestureDetector(
                onTap: _openPrivacyPolicy,
                child: Text(
                  'Privacy Policy',
                  style: AppTypography.font(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '.',
                style: AppTypography.font(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
