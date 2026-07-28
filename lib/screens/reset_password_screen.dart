import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/password_requirements.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_refreshRequirements);
  }

  @override
  void dispose() {
    _passwordCtrl.removeListener(_refreshRequirements);
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _refreshRequirements() {
    if (mounted) setState(() {});
  }

  Future<void> _handleResetPassword() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _submitting = true);
    try {
      await AuthService.instance.updatePassword(_passwordCtrl.text);
      if (!mounted) return;
      setState(() => _success = true);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _goToLogin() async {
    await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MotoMapColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _success ? _buildSuccessState() : _buildFormState(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: MotoMapColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset,
              size: 30,
              color: MotoMapColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 20),
          Text('Reset Password', style: MotoMapText.headlineMd),
          const SizedBox(height: 8),
          Text(
            'Create a new password for your account',
            style: MotoMapText.bodyMd.copyWith(
              color: MotoMapColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'New Password',
              style: MotoMapText.bodyMd.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          _buildPasswordField(
            controller: _passwordCtrl,
            hint: 'Enter a new password',
            obscureText: _obscurePassword,
            onToggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            validator: (v) {
              if (!PasswordRules.isValid(v ?? '')) {
                return 'Password does not meet every requirement';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: PasswordRequirements(password: _passwordCtrl.text),
          ),
          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Confirm Password',
              style: MotoMapText.bodyMd.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          _buildPasswordField(
            controller: _confirmPasswordCtrl,
            hint: 'Confirm your new password',
            obscureText: _obscureConfirmPassword,
            onToggle: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            validator: (v) {
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: MotoMapColors.primaryContainer,
                foregroundColor: MotoMapColors.onPrimaryContainer,
                disabledBackgroundColor: MotoMapColors.primaryContainer
                    .withValues(alpha: 0.4),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MotoMapColors.onPrimaryContainer,
                      ),
                    )
                  : Text(
                      'Reset Password',
                      style: MotoMapText.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: MotoMapColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            size: 32,
            color: MotoMapColors.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 20),
        Text('Password Updated', style: MotoMapText.headlineMd),
        const SizedBox(height: 8),
        Text(
          'Your password has been reset. Sign in with your new password.',
          style: MotoMapText.bodyMd.copyWith(
            color: MotoMapColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _goToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: MotoMapColors.primaryContainer,
              foregroundColor: MotoMapColors.onPrimaryContainer,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Text(
              'Back to Sign In',
              style: MotoMapText.bodyLg.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: MotoMapText.bodyMd,
      cursorColor: MotoMapColors.primary,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: MotoMapColors.surfaceContainerHigh,
        hintText: hint,
        hintStyle: MotoMapText.bodyMd.copyWith(
          color: MotoMapColors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: MotoMapColors.onSurfaceVariant,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: MotoMapColors.onSurfaceVariant,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: MotoMapColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: MotoMapColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: MotoMapColors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MotoMapColors.error),
        ),
      ),
    );
  }
}
