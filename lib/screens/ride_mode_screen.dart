import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/ride_data.dart';
import '../services/elm327_service.dart';
import '../services/ride_recorder_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/motomap_map.dart';

class RideModeScreen extends StatefulWidget {
  const RideModeScreen({required this.plan, super.key});

  final RoutePlan plan;

  @override
  State<RideModeScreen> createState() => _RideModeScreenState();
}

class _RideModeScreenState extends State<RideModeScreen> {
  final _recorder = RideRecorderService.instance;
  MapLibreMapController? _mapController;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    if (_recorder.status == RideRecorderStatus.completed) _recorder.reset();
    _recorder.addListener(_changed);
    Elm327Service.instance.addListener(_changed);
  }

  @override
  void dispose() {
    _recorder.removeListener(_changed);
    Elm327Service.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_recorder.status == RideRecorderStatus.completed && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  Future<void> _start() async {
    try {
      await _recorder.start(widget.plan);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_recorder.errorMessage ?? error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active =
        _recorder.isActive || _recorder.status == RideRecorderStatus.completed;
    final route = active
        ? _recorder.navigationCoordinates
        : widget.plan.coordinates;
    return PopScope(
      canPop: !_recorder.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _recorder.isActive) _showBackgroundMessage();
      },
      child: Scaffold(
        backgroundColor: MotoMapColors.background,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MotoMapView(
                  route: route,
                  traveled: _recorder.traveledCoordinates,
                  currentLocation: _recorder.currentLocation,
                  followLocation:
                      _recorder.status == RideRecorderStatus.recording,
                  onControllerReady: (controller) =>
                      _mapController = controller,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            MotoMapColors.background.withValues(alpha: 0.72),
                            Colors.transparent,
                            MotoMapColors.background.withValues(alpha: 0.94),
                          ],
                          stops: const [0, 0.42, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _topBar(),
                        if (active) ...[
                          const SizedBox(height: 8),
                          _ElmRideStatus(service: Elm327Service.instance),
                        ],
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            children: [
                              _MapControl(
                                icon: Icons.add_rounded,
                                onTap: () => _mapController?.animateCamera(
                                  CameraUpdate.zoomBy(1),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _MapControl(
                                icon: Icons.remove_rounded,
                                onTap: () => _mapController?.animateCamera(
                                  CameraUpdate.zoomBy(-1),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _MapControl(
                                icon: Icons.my_location_rounded,
                                onTap: _centerCurrentLocation,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        active ? _activePanel() : _startPanel(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final remainingKm =
        widget.plan.distanceKm *
        (1 - (_recorder.completionPercent / 100).clamp(0, 1));
    return Row(
      children: [
        IconButton.filled(
          onPressed: _recorder.isActive
              ? _showBackgroundMessage
              : () => Navigator.pop(context),
          icon: Icon(
            _recorder.isActive ? Icons.expand_more_rounded : Icons.close,
          ),
          style: IconButton.styleFrom(
            backgroundColor: MotoMapColors.background.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: MotoMapColors.background.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _recorder.isActive
                      ? '${remainingKm.toStringAsFixed(1)} km remaining · '
                            '${_formatDuration(_recorder.elapsedDuration)} elapsed'
                      : '${widget.plan.distanceKm.toStringAsFixed(1)} km · '
                            '${_formatDuration(widget.plan.duration)} estimated',
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
    );
  }

  Widget _startPanel() {
    return SurfaceCard(
      color: MotoMapColors.background.withValues(alpha: 0.96),
      child: Column(
        children: [
          const Icon(
            Icons.navigation_rounded,
            size: 34,
            color: MotoMapColors.primary,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to ride?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Start is manual. GPS, elapsed time, route progress, and available ELM327 data will be recorded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: _recorder.status == RideRecorderStatus.starting
                ? 'Starting GPS…'
                : 'Start ride',
            icon: Icons.play_arrow_rounded,
            onPressed: _recorder.status == RideRecorderStatus.starting
                ? null
                : _start,
          ),
        ],
      ),
    );
  }

  Widget _activePanel() {
    final maneuver = _recorder.currentManeuver;
    final nextDistance = _recorder.distanceToNextManeuverMeters;
    final snapshot = Elm327Service.instance.ecuAvailable
        ? Elm327Service.instance.latestSnapshot
        : null;
    return Column(
      children: [
        SurfaceCard(
          color: MotoMapColors.background.withValues(alpha: 0.96),
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: MotoMapColors.primary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _maneuverIcon(maneuver?.type),
                      size: 31,
                      color: MotoMapColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nextDistance == null
                              ? 'Following route'
                              : nextDistance < 1000
                              ? '${nextDistance.round()} m'
                              : '${(nextDistance / 1000).toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: MotoMapColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          maneuver?.instruction ??
                              'Continue on the highlighted road',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _recorder.voiceMuted
                        ? 'Enable voice'
                        : 'Mute voice',
                    onPressed: () =>
                        _recorder.setVoiceMuted(!_recorder.voiceMuted),
                    icon: Icon(
                      _recorder.voiceMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _RideStat(
                    label: 'SPEED',
                    value: _recorder.currentSpeedKph.toStringAsFixed(0),
                    unit: 'km/h',
                  ),
                  _RideStat(
                    label: 'ELAPSED',
                    value: _formatClock(_recorder.elapsedDuration),
                    unit: _recorder.isPaused ? 'paused' : 'total',
                  ),
                  _RideStat(
                    label: 'MOVING',
                    value: _formatClock(_recorder.movingDuration),
                    unit: 'ride time',
                  ),
                ],
              ),
              const Divider(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _RideStat(
                    label: 'DISTANCE',
                    value: _recorder.distanceKm.toStringAsFixed(1),
                    unit: 'km',
                  ),
                  _RideStat(
                    label: 'RPM',
                    value: snapshot?.engineRpm?.toStringAsFixed(0) ?? 'N/A',
                    unit: snapshot?.engineRpm == null ? '' : 'rpm',
                  ),
                  _RideStat(
                    label: 'ENGINE',
                    value:
                        snapshot?.coolantTemperatureC?.toStringAsFixed(0) ??
                        'N/A',
                    unit: snapshot?.coolantTemperatureC == null ? '' : '°C',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: _recorder.isPaused ? 'Continue' : 'Pause',
                icon: _recorder.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                secondary: true,
                onPressed: _recorder.status == RideRecorderStatus.finishing
                    ? null
                    : _recorder.isPaused
                    ? _recorder.resume
                    : _recorder.pause,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: PrimaryButton(
                label: _recorder.status == RideRecorderStatus.finishing
                    ? 'Saving…'
                    : 'End ride',
                icon: Icons.stop_rounded,
                onPressed: _recorder.status == RideRecorderStatus.finishing
                    ? null
                    : _confirmFinish,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _centerCurrentLocation() async {
    final location = _recorder.currentLocation;
    if (location == null) return;
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        16,
      ),
    );
  }

  void _showBackgroundMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ride recording stays open here. Pause or end the ride before leaving.',
        ),
      ),
    );
  }

  Future<void> _confirmFinish() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: MotoMapColors.surfaceContainer,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('End this ride?', style: MotoMapText.headlineMd),
              const SizedBox(height: 8),
              const Text(
                'Elapsed time, moving time, pauses, GPS route, scores, and available motorcycle readings will be saved.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Save and finish',
                icon: Icons.flag_rounded,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep riding'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await _recorder.finish();
  }

  Future<void> _showResult() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: MotoMapColors.surfaceContainer,
      builder: (context) => _RideResult(recorder: _recorder),
    );
    if (!mounted) return;
    _recorder.reset();
    Navigator.pop(context, true);
  }

  static IconData _maneuverIcon(int? type) => switch (type) {
    9 || 10 || 11 || 12 || 13 => Icons.turn_right_rounded,
    14 || 15 || 16 || 17 || 18 => Icons.turn_left_rounded,
    26 || 27 => Icons.roundabout_right_rounded,
    _ => Icons.straight_rounded,
  };

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }

  static String _formatClock(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

class _RideResult extends StatelessWidget {
  const _RideResult({required this.recorder});

  final RideRecorderService recorder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 50,
            color: MotoMapColors.success,
          ),
          const SizedBox(height: 10),
          Text(
            'Ride saved',
            textAlign: TextAlign.center,
            style: MotoMapText.headlineLg,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ResultMetric(
                  label: 'DISTANCE',
                  value: '${recorder.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultMetric(
                  label: 'ELAPSED',
                  value: _RideModeScreenState._formatDuration(
                    recorder.elapsedDuration,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultMetric(
                  label: 'MOVING',
                  value: _RideModeScreenState._formatDuration(
                    recorder.movingDuration,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ResultMetric(
                  label: 'RIDE SCORE',
                  value: '${recorder.ridingScore}/100',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultMetric(
                  label: 'BIKE HEALTH',
                  value: recorder.motorcycleHealthScore == null
                      ? 'N/A'
                      : '${recorder.motorcycleHealthScore}/100',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultMetric(
                  label: recorder.fuelIsEstimated ? 'FUEL EST.' : 'FUEL',
                  value: recorder.fuelConsumedLiters == null
                      ? 'N/A'
                      : '${recorder.fuelConsumedLiters!.toStringAsFixed(2)} L',
                ),
              ),
            ],
          ),
          if (recorder.fuelIsEstimated) ...[
            const SizedBox(height: 10),
            const Text(
              'Fuel is estimated from GPS distance and motorcycle details because real ECU fuel-rate data was unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: MotoMapColors.warning),
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'View in Completed rides',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(10),
    radius: 14,
    child: Column(
      children: [
        Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _ElmRideStatus extends StatelessWidget {
  const _ElmRideStatus({required this.service});

  final Elm327Service service;

  @override
  Widget build(BuildContext context) {
    final hasCodes = service.latestTroubleCodes.isNotEmpty;
    final elm = service.isConnected;
    final ecu = service.ecuAvailable;
    final text = hasCodes
        ? '${service.latestTroubleCodes.length} ECU fault code(s): '
              '${service.latestTroubleCodes.map((code) => code.code).join(', ')}'
        : elm && ecu
        ? 'ELM327 CONNECTED · ECU CONNECTED'
        : elm
        ? 'ELM327 CONNECTED · ECU NOT CONNECTED'
        : 'ELM327 NOT CONNECTED · ECU NOT CONNECTED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: MotoMapColors.background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasCodes ? MotoMapColors.error : MotoMapColors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasCodes ? Icons.warning_amber_rounded : Icons.bluetooth_rounded,
            size: 18,
            color: hasCodes ? MotoMapColors.error : MotoMapColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
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
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: onTap,
    icon: Icon(icon, size: 19),
    style: IconButton.styleFrom(
      backgroundColor: MotoMapColors.background.withValues(alpha: 0.9),
    ),
  );
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
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      Text(
        unit,
        style: const TextStyle(
          fontSize: 8,
          color: MotoMapColors.onSurfaceVariant,
        ),
      ),
    ],
  );
}
