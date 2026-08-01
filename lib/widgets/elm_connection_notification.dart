import 'dart:async';

import 'package:flutter/material.dart';

import '../services/elm327_service.dart';
import '../theme/motomap_colors.dart';

class ElmConnectionNotificationHost extends StatefulWidget {
  const ElmConnectionNotificationHost({required this.child, super.key});

  final Widget child;

  @override
  State<ElmConnectionNotificationHost> createState() =>
      _ElmConnectionNotificationHostState();
}

class _ElmConnectionNotificationHostState
    extends State<ElmConnectionNotificationHost> {
  Timer? _hideTimer;
  String? _lastSignature;
  _ElmNotice? _notice;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Elm327Service.instance.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    Elm327Service.instance.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged() {
    final service = Elm327Service.instance;
    if (service.status == ElmConnectionStatus.connecting ||
        service.status == ElmConnectionStatus.initializing ||
        service.status == ElmConnectionStatus.unsupported) {
      return;
    }

    final elmConnected = service.isConnected;
    final ecuConnected = service.ecuAvailable;
    final signature = '$elmConnected:$ecuConnected';
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    final notice = switch ((elmConnected, ecuConnected)) {
      (true, true) => const _ElmNotice(
        message: 'ELM327 and ECU connected',
        icon: Icons.check_circle_rounded,
        color: MotoMapColors.success,
      ),
      (true, false) => const _ElmNotice(
        message: 'ELM327 connected',
        icon: Icons.bluetooth_connected_rounded,
        color: MotoMapColors.warning,
      ),
      (false, true) => const _ElmNotice(
        message: 'ECU connected',
        icon: Icons.check_circle_outline_rounded,
        color: MotoMapColors.success,
      ),
      (false, false) => const _ElmNotice(
        message: 'ELM327 and ECU not connected',
        icon: Icons.bluetooth_disabled_rounded,
        color: MotoMapColors.error,
      ),
    };

    _hideTimer?.cancel();
    if (mounted) {
      setState(() {
        _notice = notice;
        _visible = true;
      });
    }
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    return Stack(
      children: [
        widget.child,
        if (notice != null)
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: !_visible,
                child: AnimatedSlide(
                  offset: _visible ? Offset.zero : const Offset(0, -1.4),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _visible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Material(
                          color: MotoMapColors.surfaceContainerHighest,
                          elevation: 10,
                          shadowColor: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: notice.color.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  notice.icon,
                                  color: notice.color,
                                  size: 21,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    notice.message,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ElmNotice {
  const _ElmNotice({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;
}
