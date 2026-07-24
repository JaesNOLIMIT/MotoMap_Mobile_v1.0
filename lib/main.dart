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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: MotoMapColors.background,
        fontFamily: 'Manrope',
        colorScheme: ColorScheme.dark(
          surface: MotoMapColors.surface,
          primary: MotoMapColors.primary,
          onPrimary: MotoMapColors.onPrimary,
          primaryContainer: MotoMapColors.primaryContainer,
          onPrimaryContainer: MotoMapColors.onPrimaryContainer,
          error: MotoMapColors.error,
        ),
      ),
      // App always opens on the splash screen; it navigates itself to
      // LoginScreen after its ~2s animation finishes.
      home: const SplashScreen(),

      // If you use a deep-link package (app_links / uni_links / go_router)
      // to catch the "reset password" email link, push ResetPasswordScreen
      // from that handler instead of a named route, e.g.:
      //
      // final uri = Uri.parse(incomingLink);
      // if (uri.path == '/reset-password') {
      //   navigatorKey.currentState?.push(MaterialPageRoute(
      //     builder: (_) => ResetPasswordScreen(
      //       resetToken: uri.queryParameters['token'],
      //     ),
      //   ));
      // }
    );
  }
}
