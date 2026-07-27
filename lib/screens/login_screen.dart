import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import '../widgets/create_account_sheet.dart';
import '../widgets/forgot_password_sheet.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MotoMapColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Icon(Icons.two_wheeler, size: 44, color: MotoMapColors.primary),
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
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: MotoMapColors.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => showForgotPasswordSheet(context),
                    child: Text(
                      'Forgot password?',
                      style: MotoMapText.bodyMd.copyWith(
                        color: MotoMapColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MotoMapColors.primaryContainer,
                      foregroundColor: MotoMapColors.onPrimaryContainer,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In',
                          style: MotoMapText.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            color: MotoMapColors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: MotoMapColors.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "New to MotoMap? ",
                      style: MotoMapText.bodyMd.copyWith(
                        color: MotoMapColors.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      // This is the key line: tapping "Sign up" opens the
                      // Create Account bottom sheet from create_account_sheet.dart.
                      onTap: () => showCreateAccountSheet(context),
                      child: Text(
                        'Sign up',
                        style: MotoMapText.bodyMd.copyWith(
                          color: MotoMapColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: MotoMapText.bodyMd,
      cursorColor: MotoMapColors.primary,
      decoration: InputDecoration(
        filled: true,
        fillColor: MotoMapColors.surface,
        hintText: hint,
        hintStyle: MotoMapText.bodyMd.copyWith(
          color: MotoMapColors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(icon, color: MotoMapColors.onSurfaceVariant, size: 20),
        suffixIcon: suffixIcon,
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
      ),
    );
  }
}
