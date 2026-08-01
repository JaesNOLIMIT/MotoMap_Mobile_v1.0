import 'dart:async';

import 'package:flutter/material.dart';

import '../models/diagnostic_data.dart';
import '../services/elm327_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';

class RideModeScreen extends StatefulWidget {
  const RideModeScreen({
    required this.routeName,
    required this.distance,
    required this.variant,
    super.key,
  });

  final String routeName;
  final String distance;
  final int variant;

  @override
  State<RideModeScreen> createState() => _RideModeScreenState();
}

class _RideModeScreenState extends State<RideModeScreen> {
  bool muted = false;

  @override
  void initState() {
    super.initState();
    Elm327Service.instance.addListener(_elmChanged);
    unawaited(
      Elm327Service.instance.startLiveMonitoring(
        type: DiagnosticSessionType.ride,
      ),
    );
  }

  @override
  void dispose() {
    Elm327Service.instance.removeListener(_elmChanged);
    unawaited(Elm327Service.instance.stopLiveMonitoring());
    super.dispose();
  }

  void _elmChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final elm = Elm327Service.instance;
    final liveSnapshot = elm.isConnected && elm.ecuAvailable
        ? elm.latestSnapshot
        : null;
    return Scaffold(
      backgroundColor: MotoMapColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RouteArtwork(
                height: MediaQuery.sizeOf(context).height,
                variant: widget.variant,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        MotoMapColors.background.withValues(alpha: 0.35),
                        Colors.transparent,
                        MotoMapColors.background.withValues(alpha: 0.92),
                      ],
                      stops: const [0, 0.54, 1],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton.filled(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: MotoMapColors.background
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: MotoMapColors.background.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.routeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.distance} · 2h 48m remaining',
                                    style: const TextStyle(
                                      color: MotoMapColors.onSurfaceVariant,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ElmRideStatus(service: Elm327Service.instance),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          children: [
                            _MapControl(icon: Icons.add_rounded, onTap: () {}),
                            const SizedBox(height: 6),
                            _MapControl(
                              icon: Icons.remove_rounded,
                              onTap: () {},
                            ),
                            const SizedBox(height: 12),
                            _MapControl(
                              icon: Icons.my_location_rounded,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SurfaceCard(
                        padding: const EdgeInsets.all(14),
                        color: MotoMapColors.background.withValues(alpha: 0.94),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: MotoMapColors.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.turn_right_rounded,
                                    size: 34,
                                    color: MotoMapColors.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '500 m',
                                        style: TextStyle(
                                          color: MotoMapColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Turn right onto Marcos Highway',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => muted = !muted),
                                  icon: Icon(
                                    muted
                                        ? Icons.volume_off_rounded
                                        : Icons.volume_up_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _RideStat(
                                  label: 'SPEED',
                                  value:
                                      liveSnapshot?.vehicleSpeedKph
                                          ?.toStringAsFixed(0) ??
                                      'N/A',
                                  unit: liveSnapshot?.vehicleSpeedKph == null
                                      ? ''
                                      : 'km/h',
                                ),
                                _RideStat(
                                  label: 'RPM',
                                  value:
                                      liveSnapshot?.engineRpm?.toStringAsFixed(
                                        0,
                                      ) ??
                                      'N/A',
                                  unit: liveSnapshot?.engineRpm == null
                                      ? ''
                                      : 'rpm',
                                ),
                                _RideStat(
                                  label: 'ENGINE',
                                  value:
                                      liveSnapshot?.coolantTemperatureC
                                          ?.toStringAsFixed(0) ??
                                      'N/A',
                                  unit:
                                      liveSnapshot?.coolantTemperatureC == null
                                      ? ''
                                      : '°C',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Emergency',
                              icon: Icons.sos_rounded,
                              secondary: true,
                              onPressed: () => showAppMessage(
                                context,
                                'Emergency contacts are ready.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: 'End ride',
                              icon: Icons.stop_rounded,
                              onPressed: () => _showEndRide(context),
                            ),
                          ),
                        ],
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

  void _showEndRide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MotoMapColors.surfaceContainer,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('End this ride?', style: MotoMapText.headlineMd),
              const SizedBox(height: 8),
              Text(
                'Your route and ride stats will be saved to Completed.',
                textAlign: TextAlign.center,
                style: MotoMapText.bodyMd.copyWith(
                  color: MotoMapColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Save and finish',
                icon: Icons.flag_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElmRideStatus extends StatelessWidget {
  const _ElmRideStatus({required this.service});

  final Elm327Service service;

  @override
  Widget build(BuildContext context) {
    final hasCodes = service.latestTroubleCodes.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: (hasCodes ? MotoMapColors.error : MotoMapColors.background)
            .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasCodes
              ? MotoMapColors.error.withValues(alpha: 0.6)
              : MotoMapColors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasCodes
                ? Icons.warning_amber_rounded
                : service.isConnected
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_disabled_rounded,
            size: 18,
            color: hasCodes ? MotoMapColors.error : MotoMapColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              hasCodes
                  ? '${service.latestTroubleCodes.length} ECU fault code(s): ${service.latestTroubleCodes.map((code) => code.code).join(', ')}'
                  : service.statusLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      style: IconButton.styleFrom(
        backgroundColor: MotoMapColors.background.withValues(alpha: 0.88),
      ),
    );
  }
}

class _RideStat extends StatelessWidget {
  const _RideStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 8)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 9,
            color: MotoMapColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
