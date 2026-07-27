import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/motomap_colors.dart';

void main() {
  runApp(const MotoMapApp());
}

class MotoMapApp extends StatelessWidget {
  const MotoMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoMap',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _theme,
      darkTheme: _theme,
      home: const SplashScreen(),
    );
  }

  ThemeData get _theme {
    final scheme = ColorScheme.dark(
      surface: MotoMapColors.surface,
      primary: MotoMapColors.primary,
      onPrimary: MotoMapColors.onPrimary,
      primaryContainer: MotoMapColors.primaryContainer,
      onPrimaryContainer: MotoMapColors.onPrimaryContainer,
      secondary: MotoMapColors.secondary,
      onSecondary: MotoMapColors.onSecondary,
      error: MotoMapColors.error,
      outline: MotoMapColors.outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MotoMapColors.background,
      colorScheme: scheme,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: MotoMapColors.outlineVariant,
      textTheme: const TextTheme(
        headlineLarge: MotoMapText.headlineLg,
        headlineMedium: MotoMapText.headlineMd,
        titleLarge: MotoMapText.title,
        bodyLarge: MotoMapText.bodyLg,
        bodyMedium: MotoMapText.bodyMd,
        labelSmall: MotoMapText.labelCaps,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MotoMapColors.background,
        foregroundColor: MotoMapColors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MotoMapColors.surfaceContainer,
        hintStyle: const TextStyle(color: MotoMapColors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MotoMapColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MotoMapColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MotoMapColors.primary),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MotoMapColors.surfaceContainerHighest,
        contentTextStyle: MotoMapText.bodyMd,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
