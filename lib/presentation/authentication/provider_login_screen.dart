import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/constants/app_assets.dart';
import '../../core/auth/auth_service.dart';
import '../widgets/sporve_button.dart';
import 'controllers/auth_provider.dart';

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.signIn(email, password);
    if (!mounted) return;

    switch (result.status) {
      case AuthStatus.signedIn:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: AppColors.positive,
          ),
        );
        Get.offAllNamed(authProvider.routeForRole(result.user?.role));
        break;
      case AuthStatus.emailConfirmationRequired:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please confirm your email from the link we sent, then log in.',
            ),
            backgroundColor: AppColors.negative,
          ),
        );
        break;
      case AuthStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Login failed'),
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
                    'Provider Portal',
                    style: AppTypography.font(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage your sports program',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: Get.height * 0.65),
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
                  _buildTextField(
                    controller: _emailController,
                    label: 'EMAIL ADDRESS',
                    hint: 'provider@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'PASSWORD',
                    hint: 'Your password',
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggleVisibility: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                      child: Text(
                        'Forgot password?',
                        style: AppTypography.font(
                          color: AppColors.slateText,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SporveButton(
                    'Sign in to portal',
                    onPressed: authProvider.isLoading ? null : _handleLogin,
                    loading: authProvider.isLoading,
                    variant: SporveButtonVariant.primary,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Want to join as a provider? ',
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.onboarding),
                        child: Text(
                          'Apply Now',
                          style: AppTypography.font(
                            color: AppColors.slateText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
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
