import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import './controllers/onboarding_controller.dart';

class OnboardingSelectionScreen extends StatefulWidget {
  const OnboardingSelectionScreen({super.key});

  @override
  State<OnboardingSelectionScreen> createState() =>
      _OnboardingSelectionScreenState();
}

class _OnboardingSelectionScreenState extends State<OnboardingSelectionScreen> {
  // The committed role drives the create/sign-in stage; the PENDING role is the
  // highlighted-but-not-yet-advanced choice (slate border) before Continue.
  bool? _providerRole;
  bool? _pendingRole;

  void _pickRole(bool isProvider) => setState(() => _pendingRole = isProvider);

  void _confirmRole(BuildContext context) {
    final role = _pendingRole;
    if (role == null) return;
    context.read<OnboardingProvider>().setServiceProvider(role);
    setState(() => _providerRole = role);
  }

  void _resetRole() => setState(() {
    _providerRole = null;
    _pendingRole = null;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Full-screen on black — the role fork owns the whole surface (spec §6).
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _providerRole == null ? () => Get.back() : _resetRole,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _providerRole == null
                ? _roleStage(context)
                : _actionStage(context, _providerRole!),
          ),
        ),
      ),
    );
  }

  Widget _roleStage(BuildContext context) => Column(
    key: const ValueKey('role-stage'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      Text(
        'How will you use Sporve?',
        style: AppTypography.font(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Choose a role before creating or signing in to an account.',
        style: AppTypography.font(color: AppColors.textSecondary, fontSize: 15),
      ),
      const SizedBox(height: 32),
      _buildOptionCard(
        title: "I'm looking for training",
        subtitle:
            'Discover background-check-verified coaches, compare programs, and book training.',
        icon: Icons.directions_run,
        accent: AppColors.slateText,
        tint: AppColors.slateTint,
        selected: _pendingRole == false,
        onTap: () => _pickRole(false),
      ),
      const SizedBox(height: 20),
      _buildOptionCard(
        title: 'I provide training',
        subtitle:
            'Create listings, manage sessions, and communicate with families.',
        icon: Icons.person_search,
        accent: AppColors.slateText,
        tint: AppColors.slateTint,
        selected: _pendingRole == true,
        onTap: () => _pickRole(true),
      ),
      const Spacer(),
      // Explicit Continue — the choice is confirmed with a slate border first,
      // then advances (no instant-advance).
      _buildContinueButton(context),
      const SizedBox(height: 24),
    ],
  );

  Widget _buildContinueButton(BuildContext context) {
    final enabled = _pendingRole != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Continue',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _confirmRole(context) : null,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: enabled ? AppColors.slate : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: enabled ? AppColors.slate : AppColors.hairline,
              ),
            ),
            child: Center(
              child: Text(
                'Continue',
                style: AppTypography.font(
                  color: enabled ? Colors.white : AppColors.textTertiary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionStage(BuildContext context, bool isProvider) {
    final roleName = isProvider ? 'provider' : 'athlete or family';
    return Column(
      key: const ValueKey('action-stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isProvider ? AppColors.blueTint : AppColors.slateTint,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isProvider ? 'Provider' : 'Athlete & family',
            style: AppTypography.font(
              color: isProvider ? AppColors.blueText : AppColors.slateText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Continue as a $roleName',
          style: AppTypography.font(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Create a new $roleName account or sign in to one you already have.',
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _buildActionCard(
          title: isProvider
              ? 'Create provider account'
              : 'Create athlete account',
          subtitle: 'Set up your email account.',
          primary: true,
          onTap: () => Get.toNamed(AppRoutes.signup),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          title: isProvider ? 'Sign in as a provider' : 'Sign in as an athlete',
          subtitle: 'Use an existing Sporve account.',
          primary: false,
          onTap: () => Get.toNamed(
            isProvider ? AppRoutes.providerLogin : AppRoutes.login,
          ),
        ),
        const Spacer(),
        Center(
          child: TextButton(
            onPressed: _resetRole,
            child: Text(
              'Choose a different role',
              style: AppTypography.font(
                color: AppColors.slateText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Color tint,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Ink(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              // Slate border on the selected state (spec §6).
              border: Border.all(
                color: selected ? AppColors.slate : AppColors.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.font(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.font(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selection indicator (not a forward arrow — selecting does not
                // instantly advance; Continue does).
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.slate : AppColors.textTertiary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required bool primary,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: '$title. $subtitle',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primary ? AppColors.slate : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: primary ? AppColors.slate : AppColors.hairline,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.font(
                        color: primary ? Colors.white : AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.font(
                        color: primary
                            ? Colors.white.withValues(alpha: 0.72)
                            : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: primary ? Colors.white : AppColors.slateText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
