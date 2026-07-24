import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';

/// Call this from the "Forgot password?" link on the login screen:
///
/// ```dart
/// TextButton(
///   onPressed: () => showForgotPasswordSheet(context),
///   child: const Text('Forgot password?'),
/// )
/// ```
Future<void> showForgotPasswordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => const ForgotPasswordSheet(),
  );
}

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key});

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  bool _linkSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _submitting = true);

    // TODO: wire this up to your auth service, e.g.:
    // await authService.sendPasswordResetEmail(_emailCtrl.text.trim());
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _linkSent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: MotoMapColors.surfaceContainerHigh,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              _buildHeader(context),
              const Divider(
                height: 1,
                color: MotoMapColors.outlineVariant,
                thickness: 0.4,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forgot Password',
                        style: MotoMapText.headlineMd,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email to reset your password',
                        style: MotoMapText.bodyMd.copyWith(
                          color: MotoMapColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      if (_linkSent) ...[
                        _buildSuccessBanner(),
                        const SizedBox(height: 20),
                      ],

                      Text(
                        'Email',
                        style: MotoMapText.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_linkSent,
                        style: MotoMapText.bodyMd,
                        cursorColor: MotoMapColors.primary,
                        validator: (v) {
                          if (v == null || !v.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: MotoMapColors.surface,
                          hintText: 'Enter your email address',
                          hintStyle: MotoMapText.bodyMd.copyWith(
                            color: MotoMapColors.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: MotoMapColors.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: MotoMapColors.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
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
                            borderSide: const BorderSide(
                              color: MotoMapColors.error,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submitting || _linkSent
                              ? null
                              : _handleSendResetLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MotoMapColors.primaryContainer,
                            foregroundColor: MotoMapColors.onPrimaryContainer,
                            disabledBackgroundColor: MotoMapColors
                                .primaryContainer
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
                                  _linkSent ? 'Link Sent' : 'Send Reset Link',
                                  style: MotoMapText.bodyLg.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MotoMapColors.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MotoMapColors.primaryContainer.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: MotoMapColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Check your inbox — we\u2019ve sent a reset link to your email.',
              style: MotoMapText.bodyMd.copyWith(
                color: MotoMapColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
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
            'Forgot Password',
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
}
