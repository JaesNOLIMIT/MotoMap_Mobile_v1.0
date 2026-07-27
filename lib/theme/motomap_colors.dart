import 'package:flutter/material.dart';

/// MotoMap's dark, road-focused visual system.
///
/// The palette deliberately uses one strong orange accent, calm green status
/// feedback, and low-contrast borders. This keeps dense ride information
/// readable without making every card compete for attention.
class MotoMapColors {
  MotoMapColors._();

  static const background = Color(0xFF090D0C);
  static const surface = Color(0xFF0E1312);
  static const surfaceContainerLowest = Color(0xFF090D0C);
  static const surfaceContainerLow = Color(0xFF111716);
  static const surfaceContainer = Color(0xFF151C1A);
  static const surfaceContainerHigh = Color(0xFF1A2321);
  static const surfaceContainerHighest = Color(0xFF222C29);
  static const surfaceVariant = surfaceContainerHigh;
  static const surfaceDim = background;
  static const surfaceBright = Color(0xFF26312E);

  static const primary = Color(0xFFFF7043);
  static const primaryContainer = Color(0xFFFF7043);
  static const onPrimary = Color(0xFF1F0B04);
  static const onPrimaryContainer = Color(0xFF1F0B04);
  static const primaryFixed = Color(0xFFFFD9CC);

  static const onSurface = Color(0xFFF4F7F5);
  static const onSurfaceVariant = Color(0xFF9DA9A4);
  static const onBackground = onSurface;
  static const outline = Color(0xFF66736E);
  static const outlineVariant = Color(0xFF25302D);

  static const success = Color(0xFF71D6A1);
  static const info = Color(0xFF79B8FF);
  static const warning = Color(0xFFFFC56E);
  static const error = Color(0xFFFF8C83);
  static const errorContainer = Color(0xFF5B1717);
  static const onError = Color(0xFF2E0907);
  static const onErrorContainer = Color(0xFFFFDAD6);

  static const secondary = Color(0xFFCDD6D2);
  static const secondaryContainer = Color(0xFF25302D);
  static const onSecondary = Color(0xFF19201E);
  static const onSecondaryContainer = Color(0xFFDCE5E1);
}

class MotoMapText {
  MotoMapText._();

  static const headlineLg = TextStyle(
    fontSize: 30,
    height: 1.15,
    letterSpacing: -0.8,
    fontWeight: FontWeight.w800,
    color: MotoMapColors.onSurface,
  );

  static const headlineMd = TextStyle(
    fontSize: 23,
    height: 1.2,
    letterSpacing: -0.35,
    fontWeight: FontWeight.w700,
    color: MotoMapColors.onSurface,
  );

  static const title = TextStyle(
    fontSize: 18,
    height: 1.25,
    letterSpacing: -0.15,
    fontWeight: FontWeight.w700,
    color: MotoMapColors.onSurface,
  );

  static const bodyLg = TextStyle(
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: MotoMapColors.onSurface,
  );

  static const bodyMd = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: MotoMapColors.onSurface,
  );

  static const labelCaps = TextStyle(
    fontSize: 10,
    height: 1.25,
    letterSpacing: 1.15,
    fontWeight: FontWeight.w800,
    color: MotoMapColors.onSurfaceVariant,
  );
}
