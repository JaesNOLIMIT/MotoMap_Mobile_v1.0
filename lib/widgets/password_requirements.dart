import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';

class PasswordRules {
  PasswordRules._();

  static bool hasMinimumLength(String value) => value.length >= 8;
  static bool hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  static bool hasLowercase(String value) => RegExp(r'[a-z]').hasMatch(value);
  static bool hasNumber(String value) => RegExp(r'[0-9]').hasMatch(value);
  static bool hasSpecial(String value) =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  static bool isValid(String value) =>
      hasMinimumLength(value) &&
      hasUppercase(value) &&
      hasLowercase(value) &&
      hasNumber(value) &&
      hasSpecial(value);
}

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _Requirement(
          label: '8+ characters',
          met: PasswordRules.hasMinimumLength(password),
        ),
        _Requirement(
          label: 'Uppercase',
          met: PasswordRules.hasUppercase(password),
        ),
        _Requirement(
          label: 'Lowercase',
          met: PasswordRules.hasLowercase(password),
        ),
        _Requirement(label: 'Number', met: PasswordRules.hasNumber(password)),
        _Requirement(
          label: 'Special character',
          met: PasswordRules.hasSpecial(password),
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? MotoMapColors.success : MotoMapColors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}
