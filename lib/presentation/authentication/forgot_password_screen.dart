import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../widgets/sporve_button.dart';
import 'controllers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _codeSent = false; // Toggles between request and reset mode

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final success = await authProvider.forgotPassword(email);

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Reset token sent to your email!'),
          backgroundColor: AppColors.positive,
        ),
      );
      setState(() {
        _codeSent = true;
      });
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Request failed. Please try again.'),
          backgroundColor: AppColors.negative,
        ),
      );
    }
  }

  Future<void> _handleResetPassword() async {
    final token = _tokenController.text.trim();
    final newPassword = _newPasswordController.text;

    if (token.isEmpty || newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the token and a password of min. 8 characters.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final success = await authProvider.resetPassword(token, newPassword);

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! Please log in.'),
          backgroundColor: AppColors.positive,
        ),
      );
      Get.offAllNamed(AppRoutes.login);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Reset failed. Please check your token.'),
          backgroundColor: AppColors.negative,
        ),
      );
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
                  Icon(
                    _codeSent ? Icons.lock_reset : Icons.lock_outline,
                    color: AppColors.slateText,
                    size: 32,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _codeSent ? 'Reset Password' : 'Forgot Password',
                    style: AppTypography.font(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Enter the reset token sent to your email and your new password.'
                        : 'Enter your email address and we\'ll send you a password reset link.',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
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
                border: const Border(top: BorderSide(color: AppColors.hairline)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.card),
                  topRight: Radius.circular(AppRadii.card),
                ),
              ),
              child: _codeSent ? _buildResetForm(authProvider) : _buildRequestForm(authProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm(AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'EMAIL ADDRESS',
          hint: 'alex@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 40),
        SporveButton(
          'Send reset link',
          onPressed: authProvider.isLoading ? null : _handleRequestReset,
          loading: authProvider.isLoading,
          variant: SporveButtonVariant.primary,
        ),
      ],
    );
  }

  Widget _buildResetForm(AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _tokenController,
          label: 'RESET TOKEN / CODE',
          hint: 'Enter token from email',
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _newPasswordController,
          label: 'NEW PASSWORD',
          hint: 'Min. 8 characters',
          isPassword: true,
          obscureText: _obscurePassword,
          onToggleVisibility: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        const SizedBox(height: 40),
        SporveButton(
          'Reset password',
          onPressed: authProvider.isLoading ? null : _handleResetPassword,
          loading: authProvider.isLoading,
          variant: SporveButtonVariant.primary,
        ),
      ],
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
            hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 15),
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
              borderSide: const BorderSide(color: AppColors.slateBorder, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
