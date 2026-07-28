import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legal_document.dart';
import '../services/auth_service.dart';
import '../theme/motomap_colors.dart';
import 'legal_documents_sheet.dart';
import 'password_requirements.dart';

Future<void> showCreateAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => const CreateAccountSheet(),
  );
}

enum _EmailStatus { idle, checking, available, taken, error }

class CreateAccountSheet extends StatefulWidget {
  const CreateAccountSheet({super.key});

  @override
  State<CreateAccountSheet> createState() => _CreateAccountSheetState();
}

class _CreateAccountSheetState extends State<CreateAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  Timer? _emailDebounce;
  DateTime? _birthDate;
  List<LegalDocument> _legalDocuments = const [];
  _EmailStatus _emailStatus = _EmailStatus.idle;
  String? _emailStatusMessage;
  String? _checkedEmail;
  String? _verificationEmail;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _loadingLegalDocuments = true;
  bool _submitting = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_scheduleEmailCheck);
    _passwordCtrl.addListener(_refreshPasswordChecklist);
    _loadLegalDocuments();
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailCtrl.removeListener(_scheduleEmailCheck);
    _passwordCtrl.removeListener(_refreshPasswordChecklist);
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _birthDateCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _refreshPasswordChecklist() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLegalDocuments() async {
    try {
      final documents = await AuthService.instance.fetchActiveLegalDocuments();
      if (!mounted) return;
      setState(() {
        _legalDocuments = documents;
        _loadingLegalDocuments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _legalDocuments = const [];
        _loadingLegalDocuments = false;
      });
    }
  }

  void _scheduleEmailCheck() {
    _emailDebounce?.cancel();
    final email = _emailCtrl.text.trim().toLowerCase();
    _checkedEmail = null;

    if (!_isValidEmail(email)) {
      setState(() {
        _emailStatus = _EmailStatus.idle;
        _emailStatusMessage = null;
      });
      return;
    }

    setState(() {
      _emailStatus = _EmailStatus.checking;
      _emailStatusMessage = 'Checking email availability…';
    });
    _emailDebounce = Timer(
      const Duration(milliseconds: 700),
      () => _checkEmail(email),
    );
  }

  Future<bool> _checkEmail(String email) async {
    try {
      final available = await AuthService.instance.isEmailAvailable(email);
      if (!mounted || email != _emailCtrl.text.trim().toLowerCase()) {
        return false;
      }
      setState(() {
        _checkedEmail = email;
        _emailStatus = available ? _EmailStatus.available : _EmailStatus.taken;
        _emailStatusMessage = available
            ? 'Email is available'
            : 'An account already uses this email';
      });
      return available;
    } on EmailAvailabilityException catch (error) {
      if (!mounted || email != _emailCtrl.text.trim().toLowerCase()) {
        return false;
      }
      setState(() {
        _emailStatus = _EmailStatus.error;
        _emailStatusMessage = error.message;
      });
      return false;
    } catch (_) {
      if (!mounted || email != _emailCtrl.text.trim().toLowerCase()) {
        return false;
      }
      setState(() {
        _emailStatus = _EmailStatus.error;
        _emailStatusMessage = 'Could not check this email. Try again.';
      });
      return false;
    }
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final lastDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: lastDate,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _birthDate = selected;
      _birthDateCtrl.text = _formatDate(selected);
    });
  }

  Future<void> _handleCreateAccount() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    if (_legalDocuments.length != LegalDocumentType.values.length) {
      _showError('Legal documents are unavailable. Please try again.');
      return;
    }
    if (!_agreedToTerms) {
      _showError('Accept the EULA, Terms, and Privacy Policy to continue.');
      return;
    }

    final email = _emailCtrl.text.trim().toLowerCase();
    _emailDebounce?.cancel();
    final emailAvailable =
        _checkedEmail == email && _emailStatus == _EmailStatus.available
        ? true
        : await _checkEmail(email);
    if (!emailAvailable || !mounted) return;

    setState(() => _submitting = true);
    try {
      final response = await AuthService.instance.signUp(
        RegistrationData(
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          username: _usernameCtrl.text,
          phoneNumber: _phoneCtrl.text,
          birthDate: _birthDate!,
          email: email,
          password: _passwordCtrl.text,
          legalDocuments: _legalDocuments,
        ),
      );
      if (!mounted) return;

      if (response.user?.identities?.isEmpty ?? false) {
        setState(() {
          _emailStatus = _EmailStatus.taken;
          _emailStatusMessage = 'An account already uses this email';
        });
        _showError('An account already uses this email.');
        return;
      }

      if (response.session == null) {
        setState(() => _verificationEmail = email);
      } else {
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      _showError(_friendlySignupError(error));
    } catch (_) {
      if (!mounted) return;
      _showError('Account creation failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resendVerification() async {
    final email = _verificationEmail;
    if (email == null || _resending) return;
    setState(() => _resending = true);
    try {
      await AuthService.instance.resendVerification(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent again.')),
      );
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.6,
      maxChildSize: 0.97,
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
              _buildHeader(),
              const Divider(height: 1, color: MotoMapColors.outlineVariant),
              if (_verificationEmail != null)
                Expanded(
                  child: _VerificationState(
                    email: _verificationEmail!,
                    resending: _resending,
                    onResend: _resendVerification,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                )
              else ...[
                Expanded(child: _buildForm(scrollController)),
                _buildStickyFooter(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildForm(ScrollController scrollController) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Account', style: MotoMapText.headlineMd),
            const SizedBox(height: 8),
            Text(
              'Create your verified MotoMap rider profile',
              style: MotoMapText.bodyMd.copyWith(
                color: MotoMapColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 26),
            _FieldLabel(icon: Icons.badge_outlined, text: 'First Name'),
            const SizedBox(height: 8),
            _MotoMapTextField(
              controller: _firstNameCtrl,
              hintText: 'Enter your first name',
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: (value) => _requiredName(value, 'First name'),
            ),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.badge_outlined, text: 'Last Name'),
            const SizedBox(height: 8),
            _MotoMapTextField(
              controller: _lastNameCtrl,
              hintText: 'Enter your last name',
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: (value) => _requiredName(value, 'Last name'),
            ),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.alternate_email, text: 'Username'),
            const SizedBox(height: 8),
            _MotoMapTextField(
              controller: _usernameCtrl,
              hintText: '5–15 characters',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                LengthLimitingTextInputFormatter(15),
              ],
              validator: (value) {
                final username = value?.trim() ?? '';
                if (!RegExp(
                  r'^[a-zA-Z0-9][a-zA-Z0-9_.]{3,13}[a-zA-Z0-9]$',
                ).hasMatch(username)) {
                  return 'Use 5–15 letters, numbers, _ or .';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            const _HelperText('Username cannot start or end with _ or .'),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.phone_outlined, text: 'Phone Number'),
            const SizedBox(height: 8),
            _MotoMapTextField(
              controller: _phoneCtrl,
              hintText: '+639171234567',
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')),
                LengthLimitingTextInputFormatter(16),
              ],
              validator: (value) {
                if (!RegExp(
                  r'^\+[1-9][0-9]{7,14}$',
                ).hasMatch(value?.trim() ?? '')) {
                  return 'Use international format, e.g. +639171234567';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.cake_outlined, text: 'Birth Date'),
            const SizedBox(height: 8),
            _MotoMapTextField(
              controller: _birthDateCtrl,
              hintText: 'Select your birth date',
              readOnly: true,
              onTap: _selectBirthDate,
              suffixIcon: const Icon(
                Icons.calendar_month_outlined,
                color: MotoMapColors.onSurfaceVariant,
              ),
              validator: (_) =>
                  _birthDate == null ? 'Birth date is required' : null,
            ),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.mail_outline, text: 'Email'),
            const SizedBox(height: 8),
            _MotoMapTextField(
              controller: _emailCtrl,
              hintText: 'rider@example.com',
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              statusColor: _emailStatusColor,
              validator: (value) => _isValidEmail(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address',
            ),
            if (_emailStatusMessage != null) ...[
              const SizedBox(height: 6),
              _EmailStatusLine(
                status: _emailStatus,
                message: _emailStatusMessage!,
              ),
            ],
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.lock_outline, text: 'Password'),
            const SizedBox(height: 8),
            _MotoMapTextField(
              controller: _passwordCtrl,
              hintText: 'Create a strong password',
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: MotoMapColors.onSurfaceVariant,
                ),
              ),
              validator: (value) => PasswordRules.isValid(value ?? '')
                  ? null
                  : 'Password does not meet every requirement',
            ),
            const SizedBox(height: 8),
            PasswordRequirements(password: _passwordCtrl.text),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.lock_outline, text: 'Confirm Password'),
            const SizedBox(height: 8),
            _MotoMapTextField(
              controller: _confirmPasswordCtrl,
              hintText: 'Enter the password again',
              obscureText: _obscureConfirmPassword,
              autocorrect: false,
              enableSuggestions: false,
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: MotoMapColors.onSurfaceVariant,
                ),
              ),
              validator: (value) =>
                  value == _passwordCtrl.text ? null : 'Passwords do not match',
            ),
            const SizedBox(height: 20),
            _LegalConsent(
              value: _agreedToTerms,
              loading: _loadingLegalDocuments,
              documentsAvailable:
                  _legalDocuments.length == LegalDocumentType.values.length,
              onChanged: (value) => setState(() => _agreedToTerms = value),
              onOpen: (type) => showLegalDocumentsSheet(
                context,
                initialType: type,
                documents: _legalDocuments.isEmpty ? null : _legalDocuments,
              ),
            ),
          ],
        ),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              'Create Account',
              textAlign: TextAlign.center,
              style: MotoMapText.bodyLg.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: MotoMapColors.surfaceContainerHigh,
        border: Border(top: BorderSide(color: MotoMapColors.outlineVariant)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: _submitting ? null : _handleCreateAccount,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MotoMapColors.onPrimary,
                  ),
                )
              : const Text('CREATE ACCOUNT'),
        ),
      ),
    );
  }

  Color? get _emailStatusColor => switch (_emailStatus) {
    _EmailStatus.available => MotoMapColors.success,
    _EmailStatus.taken || _EmailStatus.error => MotoMapColors.error,
    _EmailStatus.checking => MotoMapColors.info,
    _EmailStatus.idle => null,
  };

  static bool _isValidEmail(String email) =>
      email.length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  static String? _requiredName(String? value, String label) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return '$label is required';
    if (name.length > 80) return '$label is too long';
    return null;
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static String _friendlySignupError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered')) {
      return 'An account already uses this email.';
    }
    if (message.contains('database error')) {
      return 'That username or phone number may already be registered.';
    }
    if (message.contains('password')) {
      return 'Use 8+ characters with upper/lowercase, a number, and a symbol.';
    }
    return error.message;
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
        Icon(icon, size: 17, color: MotoMapColors.onSurface),
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
        fontSize: 11,
        color: MotoMapColors.onSurfaceVariant,
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
    this.textCapitalization = TextCapitalization.sentences,
    this.suffixIcon,
    this.inputFormatters,
    this.validator,
    this.statusColor,
    this.readOnly = false,
    this.onTap,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final Color? statusColor;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  Widget build(BuildContext context) {
    final normalBorder = statusColor ?? MotoMapColors.outlineVariant;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: normalBorder,
            width: statusColor == null ? 1 : 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: statusColor ?? MotoMapColors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MotoMapColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MotoMapColors.error, width: 1.4),
        ),
        errorStyle: const TextStyle(color: MotoMapColors.error, fontSize: 11),
      ),
    );
  }
}

class _EmailStatusLine extends StatelessWidget {
  const _EmailStatusLine({required this.status, required this.message});

  final _EmailStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      _EmailStatus.available => (
        Icons.check_circle_rounded,
        MotoMapColors.success,
      ),
      _EmailStatus.taken ||
      _EmailStatus.error => (Icons.error_outline_rounded, MotoMapColors.error),
      _EmailStatus.checking => (Icons.sync_rounded, MotoMapColors.info),
      _EmailStatus.idle => (
        Icons.info_outline_rounded,
        MotoMapColors.onSurfaceVariant,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message, style: TextStyle(color: color, fontSize: 11)),
        ),
      ],
    );
  }
}

class _LegalConsent extends StatelessWidget {
  const _LegalConsent({
    required this.value,
    required this.loading,
    required this.documentsAvailable,
    required this.onChanged,
    required this.onOpen,
  });

  final bool value;
  final bool loading;
  final bool documentsAvailable;
  final ValueChanged<bool> onChanged;
  final ValueChanged<LegalDocumentType> onOpen;

  @override
  Widget build(BuildContext context) {
    final enabled = !loading && documentsAvailable;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MotoMapColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: enabled
                ? (checked) => onChanged(checked ?? false)
                : null,
            activeColor: MotoMapColors.primary,
            checkColor: MotoMapColors.onPrimary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('I agree to the '),
                    _LegalLink(
                      label: 'EULA',
                      onTap: () => onOpen(LegalDocumentType.eula),
                    ),
                    const Text(', '),
                    _LegalLink(
                      label: 'Terms',
                      onTap: () => onOpen(LegalDocumentType.terms),
                    ),
                    const Text(', and '),
                    _LegalLink(
                      label: 'Privacy Policy',
                      onTap: () => onOpen(LegalDocumentType.privacy),
                    ),
                    const Text('.'),
                  ],
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      'Loading current legal versions…',
                      style: TextStyle(
                        color: MotoMapColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  )
                else if (!documentsAvailable)
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      'Legal documents could not be loaded.',
                      style: TextStyle(
                        color: MotoMapColors.error,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: MotoMapColors.primary,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _VerificationState extends StatelessWidget {
  const _VerificationState({
    required this.email,
    required this.resending,
    required this.onResend,
    required this.onClose,
  });

  final String email;
  final bool resending;
  final VoidCallback onResend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: MotoMapColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: MotoMapColors.success,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text('Verify your email', style: MotoMapText.headlineMd),
          const SizedBox(height: 10),
          Text(
            'We sent a verification link to',
            style: MotoMapText.bodyMd.copyWith(
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: MotoMapText.bodyLg.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            'Open the link on this device to verify your address and enter MotoMap.',
            textAlign: TextAlign.center,
            style: MotoMapText.bodyMd.copyWith(
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onClose,
              child: const Text('Back to sign in'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: resending ? null : onResend,
            icon: resending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('Resend verification email'),
          ),
        ],
      ),
    );
  }
}
