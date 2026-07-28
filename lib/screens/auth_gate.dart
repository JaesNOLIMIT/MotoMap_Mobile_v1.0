import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _subscription;
  Session? _session;
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();
    if (!SupabaseConfig.isConfigured) return;

    _session = AuthService.instance.currentSession;
    _subscription = AuthService.instance.authStateChanges.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecovery = true;
        } else if (state.event == AuthChangeEvent.signedOut) {
          _passwordRecovery = false;
        }
        _session = state.session;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_passwordRecovery && _session != null) {
      return const ResetPasswordScreen();
    }
    if (_session != null) return const MainShell();
    return const LoginScreen();
  }
}
