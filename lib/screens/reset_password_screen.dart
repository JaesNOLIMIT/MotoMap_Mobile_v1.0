import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import 'login_screen.dart';

/// The screen a user lands on after tapping the "reset password" link in
/// their email. Wire your deep-link handler (e.g. app_links, uni_links, or
/// go_router) to push this screen and pass along the token from the link, e.g.:
///
/// ```dart
/// // motomap://reset-password?token=abc123
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => ResetPasswordScreen(resetToken: uri.queryParameters['token']),
/// ));
/// ```
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.resetToken});

  /// Token parsed from the deep link. Send this along with the new password
  /// to your backend so it knows which account/request this reset belongs to.
  final String? resetToken;

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
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _submitting = true);

    // TODO: wire this up to your auth service, e.g.:
    // await authService.resetPassword(
    //   token: widget.resetToken,
    //   newPassword: _passwordCtrl.text,
    // );
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _success = true;
    });
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
              if (v == null || v.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Use at least 8 characters.',
              style: MotoMapText.bodyMd.copyWith(
                fontSize: 13,
                color: MotoMapColors.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
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
