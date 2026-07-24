import 'package:flutter/material.dart';

/// Color tokens lifted directly from the MotoMap Tailwind theme so the
/// Flutter app matches the web/HTML mock exactly.
class MotoMapColors {
  MotoMapColors._();

  static const surface = Color(0xFF121413);
  static const surfaceContainer = Color(0xFF1E201F);
  static const surfaceContainerLow = Color(0xFF1A1C1B);
  static const surfaceContainerLowest = Color(0xFF0D0F0E);
  static const surfaceContainerHigh = Color(0xFF282A29);
  static const surfaceContainerHighest = Color(0xFF333534);
  static const surfaceVariant = Color(0xFF333534);
  static const surfaceDim = Color(0xFF121413);
  static const surfaceBright = Color(0xFF383A38);
  static const background = Color(0xFF121413);

  static const primary = Color(0xFFFFB59D);
  static const onPrimary = Color(0xFF5D1900);
  static const primaryContainer = Color(0xFFFF6B35);
  static const onPrimaryContainer = Color(0xFF5F1900);
  static const primaryFixed = Color(0xFFFFDBD0);

  static const onSurface = Color(0xFFE2E3E1);
  static const onSurfaceVariant = Color(0xFFE1BFB5);
  static const onBackground = Color(0xFFE2E3E1);

  static const outline = Color(0xFFA98A80);
  static const outlineVariant = Color(0xFF594139);

  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);
  static const onError = Color(0xFF690005);
  static const onErrorContainer = Color(0xFFFFDAD6);

  static const secondary = Color(0xFFC5C6CA);
  static const secondaryContainer = Color(0xFF494C4F);
  static const onSecondary = Color(0xFF2E3134);
  static const onSecondaryContainer = Color(0xFFBABCC0);
}

/// Text styles matching the Manrope / JetBrains Mono type scale from the
/// Tailwind config (headline-lg, body-lg, body-md, label-caps, etc).
class MotoMapText {
  MotoMapText._();

  static const _manrope = 'Manrope';
  static const _jetBrainsMono = 'JetBrainsMono';

  static const headlineLg = TextStyle(
    fontFamily: _manrope,
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: -0.02 * 32,
    fontWeight: FontWeight.w700,
    color: MotoMapColors.onSurface,
  );

  static const headlineMd = TextStyle(
    fontFamily: _manrope,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    color: MotoMapColors.onSurface,
  );

  static const bodyLg = TextStyle(
    fontFamily: _manrope,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w500,
    color: MotoMapColors.onSurface,
  );

  static const bodyMd = TextStyle(
    fontFamily: _manrope,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: MotoMapColors.onSurface,
  );

  static const labelCaps = TextStyle(
    fontFamily: _jetBrainsMono,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.1 * 12,
    fontWeight: FontWeight.w700,
    color: MotoMapColors.onSurfaceVariant,
  );
}
