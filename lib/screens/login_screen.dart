import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/create_account_sheet.dart';
import '../widgets/forgot_password_sheet.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _resendingVerification = false;
  bool _showResendVerification = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _showResendVerification = false;
    });

    try {
      await AuthService.instance.signIn(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      final unverified = error.message.toLowerCase().contains(
        'email not confirmed',
      );
      setState(() => _showResendVerification = unverified);
      _showError(
        unverified
            ? 'Verify your email before signing in.'
            : _friendlyLoginError(error),
      );
    } catch (_) {
      if (mounted) {
        _showError(
          SupabaseConfig.isConfigured
              ? 'Sign in failed. Check your connection and try again.'
              : 'Supabase is not configured for this build.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_resendingVerification) return;
    setState(() => _resendingVerification = true);
    try {
      await AuthService.instance.resendVerification(_emailCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent again.')),
      );
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _resendingVerification = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MotoMapColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(
                      Icons.two_wheeler,
                      size: 44,
                      color: MotoMapColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text('MotoMap', style: MotoMapText.headlineLg),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your rider profile',
                      style: MotoMapText.bodyLg.copyWith(
                        color: MotoMapColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: 'rider@example.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(email)
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordCtrl,
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      validator: (value) => (value?.isEmpty ?? true)
                          ? 'Password is required'
                          : null,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: MotoMapColors.onSurfaceVariant,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_showResendVerification)
                          TextButton(
                            onPressed: _resendingVerification
                                ? null
                                : _resendVerification,
                            child: Text(
                              _resendingVerification
                                  ? 'Sending…'
                                  : 'Resend verification',
                            ),
                          ),
                        TextButton(
                          onPressed: () => showForgotPasswordSheet(context),
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _signIn,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MotoMapColors.onPrimary,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(_submitting ? 'Signing in…' : 'Sign In'),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'New to MotoMap? ',
                          style: MotoMapText.bodyMd.copyWith(
                            color: MotoMapColors.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () => showCreateAccountSheet(context),
                          child: const Text('Sign up'),
                        ),
                      ],
                    ),
                    if (!SupabaseConfig.isConfigured) ...[
                      const SizedBox(height: 16),
                      const _ConfigurationNotice(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      autocorrect: false,
      enableSuggestions: !obscureText,
      textCapitalization: TextCapitalization.none,
      style: MotoMapText.bodyMd,
      cursorColor: MotoMapColors.primary,
      decoration: InputDecoration(
        filled: true,
        fillColor: MotoMapColors.surface,
        hintText: hint,
        prefixIcon: Icon(icon, color: MotoMapColors.onSurfaceVariant, size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MotoMapColors.outlineVariant),
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

  static String _friendlyLoginError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    if (message.contains('rate limit')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    return error.message;
  }
}

class _ConfigurationNotice extends StatelessWidget {
  const _ConfigurationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MotoMapColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MotoMapColors.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.settings_outlined, size: 17, color: MotoMapColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Backend configuration is pending.',
              style: TextStyle(color: MotoMapColors.warning, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
