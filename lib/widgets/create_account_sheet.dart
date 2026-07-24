import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motomap_colors.dart';

/// Call this from the "Sign up" link on the login screen:
///
/// ```dart
/// TextButton(
///   onPressed: () => showCreateAccountSheet(context),
///   child: const Text('Sign up'),
/// )
/// ```
Future<void> showCreateAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => const CreateAccountSheet(),
  );
}

class CreateAccountSheet extends StatefulWidget {
  const CreateAccountSheet({super.key});

  @override
  State<CreateAccountSheet> createState() => _CreateAccountSheetState();
}

class _CreateAccountSheetState extends State<CreateAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _submitting = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _handleCreateAccount() {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Privacy Policy'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    // TODO: wire up to your auth service (fullName, username, email, password).
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: MotoMapColors.surfaceContainerHigh,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(context),
              const Divider(
                height: 1,
                color: MotoMapColors.outlineVariant,
                thickness: 0.4,
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + mediaQuery.viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Account', style: MotoMapText.headlineMd),
                        const SizedBox(height: 8),
                        Text(
                          'Join MotoMap and start mapping your rides today',
                          style: MotoMapText.bodyMd.copyWith(
                            color: MotoMapColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),

                        _FieldLabel(
                          icon: Icons.person_outline,
                          text: 'Full Name',
                        ),
                        const SizedBox(height: 8),
                        _MotoMapTextField(
                          controller: _fullNameCtrl,
                          hintText: 'Enter your full name',
                          keyboardType: TextInputType.name,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r"[a-zA-Z\s\-']"),
                            ),
                          ],
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Full name is required'
                              : null,
                        ),
                        const SizedBox(height: 6),
                        _HelperText(
                          'Only letters, spaces, hyphens, and apostrophes allowed.',
                        ),
                        const SizedBox(height: 20),

                        _FieldLabel(
                          icon: Icons.person_outline,
                          text: 'Username',
                        ),
                        const SizedBox(height: 8),
                        _MotoMapTextField(
                          controller: _usernameCtrl,
                          hintText: '5-15 characters (letters, numbers, _, .)',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9_.]'),
                            ),
                          ],
                          validator: (v) {
                            if (v == null || v.length < 5 || v.length > 15) {
                              return 'Username must be 5-15 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),
                        _HelperText(
                          'Only letters, numbers, underscores, and periods. No spaces or emojis.',
                        ),
                        const SizedBox(height: 20),

                        _FieldLabel(icon: Icons.mail_outline, text: 'Email'),
                        const SizedBox(height: 8),
                        _MotoMapTextField(
                          controller: _emailCtrl,
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || !v.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        _FieldLabel(icon: Icons.lock_outline, text: 'Password'),
                        const SizedBox(height: 8),
                        _MotoMapTextField(
                          controller: _passwordCtrl,
                          hintText: 'Create a password',
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: MotoMapColors.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        _FieldLabel(
                          icon: Icons.lock_outline,
                          text: 'Confirm Password',
                        ),
                        const SizedBox(height: 8),
                        _MotoMapTextField(
                          controller: _confirmPasswordCtrl,
                          hintText: 'Confirm your password',
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: MotoMapColors.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        _TermsCheckbox(
                          value: _agreedToTerms,
                          onChanged: (v) => setState(() => _agreedToTerms = v),
                        ),
                        const SizedBox(height: 28),

                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: MotoMapColors.outlineVariant,
                                thickness: 0.5,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text('OR', style: MotoMapText.labelCaps),
                            ),
                            const Expanded(
                              child: Divider(
                                color: MotoMapColors.outlineVariant,
                                thickness: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _AppleButton(onPressed: () {}),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              _buildStickyFooter(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: MotoMapColors.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: MotoMapColors.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            'Create Account',
            style: MotoMapText.bodyLg.copyWith(fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: MotoMapColors.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: MotoMapColors.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: MotoMapColors.outlineVariant, width: 0.4),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _submitting ? null : _handleCreateAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: MotoMapColors.primaryContainer,
            foregroundColor: MotoMapColors.onPrimaryContainer,
            disabledBackgroundColor: MotoMapColors.primaryContainer.withValues(
              alpha: 0.4,
            ),
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
                  'CREATE ACCOUNT',
                  style: MotoMapText.labelCaps.copyWith(
                    color: MotoMapColors.onPrimaryContainer,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: MotoMapColors.onSurface),
        const SizedBox(width: 8),
        Text(
          text,
          style: MotoMapText.bodyMd.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _HelperText extends StatelessWidget {
  const _HelperText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MotoMapText.bodyMd.copyWith(
        fontSize: 13,
        color: MotoMapColors.onSurfaceVariant.withValues(alpha: 0.75),
      ),
    );
  }
}

class _MotoMapTextField extends StatelessWidget {
  const _MotoMapTextField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: MotoMapText.bodyMd,
      cursorColor: MotoMapColors.primary,
      decoration: InputDecoration(
        filled: true,
        fillColor: MotoMapColors.surface,
        hintText: hintText,
        hintStyle: MotoMapText.bodyMd.copyWith(
          color: MotoMapColors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MotoMapColors.error),
        ),
        errorStyle: const TextStyle(color: MotoMapColors.error, fontSize: 12),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MotoMapColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: MotoMapColors.primaryContainer,
              checkColor: MotoMapColors.onPrimaryContainer,
              side: BorderSide(
                color: MotoMapColors.outline.withValues(alpha: 0.6),
              ),
              shape: const CircleBorder(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: MotoMapText.bodyMd.copyWith(
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: MotoMapColors.onSurface,
                      ),
                    ),
                    const TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: MotoMapColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.apple, size: 20, color: MotoMapColors.onSurface),
        label: Text(
          'Continue with Apple',
          style: MotoMapText.bodyLg.copyWith(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MotoMapColors.onSurface,
          side: BorderSide(
            color: MotoMapColors.outlineVariant.withValues(alpha: 0.4),
          ),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
