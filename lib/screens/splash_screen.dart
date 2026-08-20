import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'auth_gate.dart';

/// Shown once when the app launches. Plays a ~2 second logo animation, then
/// replaces itself with [AuthGate], which restores an existing Supabase
/// session or shows the sign-in screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Logo pops in first with a slight overshoot.
    _logoScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.6,
              end: 1.08,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 55,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.08,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 45,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.55),
          ),
        );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35),
    );

    // App name fades/slides in just after the logo settles.
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
          ),
        );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goNext();
      }
    });
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const AuthGate()),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MotoMapColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: const MotoMapBrandIcon(size: 96, radius: 28),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _titleOpacity,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: Column(
                      children: [
                        Text('MotoMap', style: MotoMapText.headlineLg),
                        const SizedBox(height: 6),
                        Text(
                          'Ride further, ride smarter',
                          style: MotoMapText.bodyMd.copyWith(
                            color: MotoMapColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
