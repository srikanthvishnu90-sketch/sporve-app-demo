import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/constants/app_assets.dart';
import '../../core/auth/auth_service.dart';
import '../onboarding/controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';
import 'controllers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _privacyAcknowledged = false;

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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out all the fields.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    // Real validation: a properly-formed email and a password Supabase accepts.
    final emailOk = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);
    if (!emailOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    if (!_privacyAcknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please acknowledge Sporve\'s Privacy Policy to continue.',
          ),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    final onboardingProvider = Provider.of<OnboardingProvider>(
      context,
      listen: false,
    );
    final String role = onboardingProvider.isServiceProvider
        ? 'provider'
        : 'searcher';

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.signUp(
      name: '$firstName $lastName'.trim(),
      email: email,
      password: password,
      role: role,
      phone: phone,
    );
    if (!mounted) return;

    switch (result.status) {
      case AuthStatus.signedIn:
        // Email confirmation is OFF — the account is active immediately.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created!'),
            backgroundColor: AppColors.positive,
          ),
        );
        // A brand-new account goes into the SETUP flow (add your athlete +
        // sports + goal for clients; identity/capacity/pricing for providers),
        // not straight to the app. Each onboarding chain ends at the main app.
        Get.offAllNamed(
          onboardingProvider.isServiceProvider
              ? AppRoutes.providerIdentity
              : AppRoutes.selectSports,
        );
        break;
      case AuthStatus.emailConfirmationRequired:
        // Email confirmation is ON — send them to the "check your email" screen.
        Get.toNamed(AppRoutes.verifyEmail);
        break;
      case AuthStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Registration failed'),
            backgroundColor: AppColors.negative,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Image.asset(AppAssets.appLogo, width: 45, height: 45),
                  const SizedBox(height: 28),
                  Text(
                    Provider.of<OnboardingProvider>(
                          context,
                          listen: false,
                        ).isServiceProvider
                        ? 'Create provider account'
                        : 'Create your account',
                    style: AppTypography.font(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (Provider.of<OnboardingProvider>(
                    context,
                    listen: false,
                  ).isServiceProvider)
                    Text(
                      'Institution: ${Provider.of<OnboardingProvider>(context, listen: false).institutionName}',
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    Provider.of<OnboardingProvider>(
                          context,
                          listen: false,
                        ).isServiceProvider
                        ? 'Final step — Your details'
                        : 'Step 1 of 2 — Your details',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final isProvider = Provider.of<OnboardingProvider>(
                            context,
                            listen: false,
                          ).isServiceProvider;
                          Get.toNamed(
                            isProvider
                                ? AppRoutes.providerLogin
                                : AppRoutes.login,
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(44, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Log in',
                          style: AppTypography.font(
                            color: AppColors.slateText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: Get.height * 0.6),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(
                  top: BorderSide(color: AppColors.hairline),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.card),
                  topRight: Radius.circular(AppRadii.card),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: 'FIRST NAME',
                          hint: 'Alex',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: 'LAST NAME',
                          hint: 'Burton',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _emailController,
                    label: 'EMAIL ADDRESS',
                    hint: 'alex@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'PHONE NUMBER',
                    hint: '+1 (555) 000-0000',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'PASSWORD',
                    hint: 'Min. 8 characters',
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggleVisibility: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _privacyAcknowledged,
                          onChanged: (v) {
                            setState(() {
                              _privacyAcknowledged = v ?? false;
                            });
                          },
                          activeColor: AppColors.slateText,
                          checkColor: AppColors.onSlate,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: const BorderSide(
                            color: AppColors.hairline,
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'I have read Sporve\'s ',
                              style: AppTypography.font(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            TextButton(
                              onPressed: _openPrivacyPolicy,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                minimumSize: const Size(44, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Privacy Policy',
                                style: AppTypography.font(
                                  color: AppColors.slateText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '.',
                              style: AppTypography.font(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SporveButton(
                    'Continue',
                    onPressed: authProvider.isLoading ? null : _handleSignup,
                    loading: authProvider.isLoading,
                    icon: Icons.arrow_forward,
                    variant: SporveButtonVariant.primary,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPassword && obscureText,
          keyboardType: keyboardType,
          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 15),
          cursorColor: AppColors.slateText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 15,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
