import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/ride_data.dart';
import '../services/motorcycle_service.dart';
import '../services/ride_repository.dart';
import '../services/routing_service.dart';
import '../services/shared_ride_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/motomap_map.dart';
import 'location_picker_screen.dart';
import 'route_detail_screen.dart';

enum PlanChoice { ai, destination, loop, surprise }

class PlanScreen extends StatefulWidget {
  const PlanScreen({required this.onOpenRides, super.key});
  final VoidCallback onOpenRides;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _codeController = TextEditingController();
  bool _working = false;
  MapPoint? _mapLocation;
  MapLibreMapController? _mapController;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMapLocation());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMapLocation() async {
    try {
      final location = await _currentLocation();
      if (mounted) {
        setState(() => _mapLocation = location);
        await _centerPlanMap(location);
      }
    } catch (_) {
      // Permission can be retried when the rider starts planning.
    }
  }

  Future<void> _openChoice(
    PlanChoice choice, {
    PlaceResult? initialDestination,
  }) async {
    final request = await Navigator.of(context).push<_PlanRequest>(
      MaterialPageRoute(
        builder: (_) => _PlanQuestionsScreen(
          choice: choice,
          initialDestination: initialDestination,
        ),
      ),
    );
    if (request != null && mounted) await _generate(request);
  }

  Future<void> _chooseDestination() async {
    try {
      final origin = _mapLocation ?? await _currentLocation();
      if (mounted && _mapLocation == null) {
        setState(() => _mapLocation = origin);
      }
      if (!mounted) return;
      final destination = await Navigator.of(context).push<PlaceResult>(
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(currentLocation: origin),
        ),
      );
      if (destination != null && mounted) {
        await _openChoice(
          PlanChoice.destination,
          initialDestination: destination,
        );
      }
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  Future<void> _showJoinRide() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Join a group ride', style: MotoMapText.headlineMd),
            const SizedBox(height: 6),
            const Text(
              'Enter the private six-character code from the ride leader.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MotoMapColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              autofocus: true,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                UpperCaseTextFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Ride code',
                hintText: 'A7K9P2',
                counterText: '',
                prefixIcon: Icon(Icons.groups_2_outlined),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Enter group ride',
              icon: Icons.login_rounded,
              onPressed: () {
                Navigator.pop(sheetContext);
                _joinSharedRide();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(_PlanRequest request) async {
    setState(() => _working = true);
    try {
      final origin = await _currentLocation();
      var destination = request.destination;
      var isLoop =
          request.choice == PlanChoice.loop ||
          request.choice == PlanChoice.surprise;
      var preference = request.preference;
      var distanceKm = request.distanceKm;
      var durationMinutes = request.durationMinutes;
      final prompt = request.prompt;

      if (request.choice == PlanChoice.ai) {
        final intent = RoutingService.instance.parsePrompt(prompt!);
        isLoop = intent.isLoop;
        preference = intent.preference;
        distanceKm =
            intent.distanceKm ??
            (intent.durationMinutes == null
                ? 50
                : intent.durationMinutes! / 60 * 45);
        durationMinutes = intent.durationMinutes;
        if (!isLoop) {
          if (intent.destinationQuery == null) {
            throw StateError(
              'Include a destination such as “ride to Tagaytay,” or ask for a loop.',
            );
          }
          final matches = await RoutingService.instance.searchPlaces(
            intent.destinationQuery!,
            near: origin,
          );
          if (matches.isEmpty) {
            throw StateError('No real destination matched that description.');
          }
          destination = matches.first;
        }
      }

      final alternatives = isLoop
          ? await _loopAlternatives(
              origin: origin,
              distanceKm:
                  distanceKm ??
                  (durationMinutes == null ? 50 : durationMinutes / 60 * 45),
              preference: preference,
              heading: request.headingDegrees,
              avoidHighways: request.avoidHighways,
              avoidTolls: request.avoidTolls,
            )
          : await RoutingService.instance.routeAlternatives(
              origin: origin,
              destination: destination!.location,
              preference: preference,
              avoidHighways: request.avoidHighways,
              avoidTolls: request.avoidTolls,
            );
      if (alternatives.isEmpty) {
        throw StateError('No usable motorcycle route was returned.');
      }
      final primaryBike = await MotorcycleService.instance
          .fetchPrimaryMotorcycle();
      final selected = alternatives.first;
      final title = isLoop
          ? '${selected.route.distanceKm.round()} km ${preference.label} Loop'
          : destination!.name;
      final plan = await RideRepository.instance.saveRoutePlan(
        route: selected.route,
        title: title,
        source: switch (request.choice) {
          PlanChoice.ai => 'smart_prompt',
          PlanChoice.surprise => 'quick_idea',
          _ => 'manual',
        },
        prompt: prompt,
        originName: 'Current location',
        destinationName: isLoop ? 'Return to start' : destination!.displayName,
        isLoop: isLoop,
        preference: selected.preference,
        requestedDistanceKm: isLoop ? distanceKm : null,
        requestedDurationMinutes: durationMinutes,
        scheduledFor: request.rideLater ? request.scheduledFor : null,
        motorcycleId: primaryBike?.id,
        departureMode: request.rideLater ? 'later' : 'now',
        avoidHighways: request.avoidHighways,
        avoidTolls: request.avoidTolls,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              RouteDetailScreen(plan: plan, alternatives: alternatives),
        ),
      );
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<List<RouteAlternative>> _loopAlternatives({
    required MapPoint origin,
    required double distanceKm,
    required RoutePreference preference,
    required double? heading,
    required bool avoidHighways,
    required bool avoidTolls,
  }) async {
    final baseHeading = heading ?? math.Random().nextInt(360).toDouble();
    final preferences = <RoutePreference>{
      preference,
      RoutePreference.fastest,
      RoutePreference.scenic,
    }.toList(growable: false);
    final results = <RouteAlternative>[];
    for (var index = 0; index < preferences.length; index++) {
      try {
        final route = await RoutingService.instance.createLoop(
          origin: origin,
          requestedDistanceKm: distanceKm,
          preference: preferences[index],
          headingDegrees: (baseHeading + index * 75) % 360,
          avoidHighways: avoidHighways,
          avoidTolls: avoidTolls,
        );
        results.add(
          RouteAlternative(
            route: route,
            preference: preferences[index],
            label: index == 0 ? 'Recommended' : preferences[index].label,
          ),
        );
      } catch (_) {
        if (results.isEmpty && index == preferences.length - 1) rethrow;
      }
    }
    return results;
  }

  Future<void> _joinSharedRide() async {
    final code = _codeController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      _message('Enter the six-character code.');
      return;
    }
    setState(() => _working = true);
    try {
      final bike = await MotorcycleService.instance.fetchPrimaryMotorcycle();
      final shared = await SharedRideService.instance.join(
        code: code,
        motorcycleId: bike?.id,
      );
      final plan = await RideRepository.instance.fetchRoutePlan(
        shared.routePlanId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RouteDetailScreen(plan: plan, sharedRide: shared),
        ),
      );
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<MapPoint> _currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on Location Services to plan from your position.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required for route planning.');
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 20),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 20),
              ),
      );
      return MapPoint(position.latitude, position.longitude);
    } on MissingPluginException {
      throw StateError('Install the latest MotoMap build to enable GPS.');
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _centerPlanMap([MapPoint? knownLocation]) async {
    try {
      final location =
          knownLocation ?? _mapLocation ?? await _currentLocation();
      if (mounted && _mapLocation != location) {
        setState(() => _mapLocation = location);
      }
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          15,
        ),
        duration: const Duration(milliseconds: 500),
      );
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MotoMapView(
            route: const [],
            currentLocation: _mapLocation,
            onControllerReady: (controller) {
              _mapController = controller;
              if (_mapLocation != null) unawaited(_centerPlanMap(_mapLocation));
            },
          ),
        ),
        Positioned(
          right: 14,
          top: MediaQuery.paddingOf(context).top + 64,
          child: IconButton.filled(
            tooltip: 'Recenter on me',
            onPressed: _working ? null : _centerPlanMap,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                const Expanded(child: MotoMapLogo(compact: true)),
                IconButton.filled(
                  tooltip: 'Saved rides',
                  onPressed: widget.onOpenRides,
                  icon: const Icon(Icons.bookmark_outline_rounded),
                ),
              ],
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.54,
          minChildSize: 0.24,
          maxChildSize: 0.88,
          snap: true,
          snapSizes: const [0.24, 0.54, 0.88],
          builder: (context, scrollController) => DecoratedBox(
            decoration: const BoxDecoration(
              color: MotoMapColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 22)],
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: MotoMapColors.outlineVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _working ? null : _chooseDestination,
                  child: const AbsorbPointer(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search a destination or place',
                        prefixIcon: Icon(Icons.search_rounded),
                        suffixIcon: Icon(Icons.mic_none_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Plan your ride', style: MotoMapText.headlineMd),
                const SizedBox(height: 4),
                const Text(
                  'Choose one way to begin. Every route uses real motorcycle roads.',
                  style: TextStyle(color: MotoMapColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                _PlanChoiceCard(
                  title: 'AI Ride Planner',
                  subtitle: 'Describe your ideal ride in your own words',
                  icon: Icons.auto_awesome_rounded,
                  featured: true,
                  onTap: () => _openChoice(PlanChoice.ai),
                ),
                const SizedBox(height: 9),
                _PlanChoiceCard(
                  title: 'Choose a destination',
                  subtitle:
                      'Search, browse nearby places, or long-press the map',
                  icon: Icons.location_on_outlined,
                  onTap: _chooseDestination,
                ),
                const SizedBox(height: 9),
                _PlanChoiceCard(
                  title: 'Plan a loop',
                  subtitle: 'Choose distance or time and return to your start',
                  icon: Icons.loop_rounded,
                  onTap: () => _openChoice(PlanChoice.loop),
                ),
                const SizedBox(height: 9),
                _PlanChoiceCard(
                  title: 'Surprise me',
                  subtitle: 'Give MotoMap your time and preferred direction',
                  icon: Icons.casino_outlined,
                  onTap: () => _openChoice(PlanChoice.surprise),
                ),
                const SizedBox(height: 9),
                _PlanChoiceCard(
                  title: 'Join a group ride',
                  subtitle: 'Enter the leader’s private six-character code',
                  icon: Icons.groups_2_outlined,
                  onTap: _showJoinRide,
                ),
              ],
            ),
          ),
        ),
        if (_working)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x99070B09),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  static String _friendlyError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
}

class _PlanChoiceCard extends StatelessWidget {
  const _PlanChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.featured = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    borderColor: featured
        ? MotoMapColors.primary.withValues(alpha: 0.55)
        : MotoMapColors.outlineVariant,
    child: Row(
      children: [
        CircleAvatar(
          radius: featured ? 25 : 22,
          backgroundColor: MotoMapColors.primary.withValues(alpha: 0.14),
          foregroundColor: MotoMapColors.primary,
          child: Icon(icon),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: MotoMapColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class _PlanRequest {
  const _PlanRequest({
    required this.choice,
    required this.preference,
    required this.rideLater,
    required this.avoidHighways,
    required this.avoidTolls,
    this.prompt,
    this.destination,
    this.distanceKm,
    this.durationMinutes,
    this.scheduledFor,
    this.headingDegrees,
  });
  final PlanChoice choice;
  final RoutePreference preference;
  final String? prompt;
  final PlaceResult? destination;
  final double? distanceKm;
  final int? durationMinutes;
  final bool rideLater;
  final DateTime? scheduledFor;
  final double? headingDegrees;
  final bool avoidHighways;
  final bool avoidTolls;
}

class _PlanQuestionsScreen extends StatefulWidget {
  const _PlanQuestionsScreen({required this.choice, this.initialDestination});
  final PlanChoice choice;
  final PlaceResult? initialDestination;

  @override
  State<_PlanQuestionsScreen> createState() => _PlanQuestionsScreenState();
}

class _PlanQuestionsScreenState extends State<_PlanQuestionsScreen> {
  final _prompt = TextEditingController();
  final _target = TextEditingController(text: '50');
  final _search = TextEditingController();
  RoutePreference _preference = RoutePreference.balanced;
  PlaceResult? _destination;
  List<PlaceResult> _results = const [];
  bool _searching = false;
  bool _rideLater = false;
  bool _targetTime = false;
  bool _avoidHighways = false;
  bool _avoidTolls = false;
  DateTime? _scheduledFor;
  int _surpriseMinutes = 120;
  double? _heading;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
  }

  @override
  void dispose() {
    _prompt.dispose();
    _target.dispose();
    _search.dispose();
    super.dispose();
  }

  String get _title => switch (widget.choice) {
    PlanChoice.ai => 'AI Ride Planner',
    PlanChoice.destination => 'Plan route',
    PlanChoice.loop => 'Plan loop',
    PlanChoice.surprise => 'Surprise mode',
  };

  Future<void> _findDestination() async {
    if (_search.text.trim().length < 2) return;
    setState(() => _searching = true);
    try {
      final results = await RoutingService.instance.searchPlaces(_search.text);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _scheduledFor ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledFor ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    setState(() {
      _scheduledFor = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _continue() {
    if (widget.choice == PlanChoice.ai && _prompt.text.trim().length < 5) {
      _error('Describe your ride first.');
      return;
    }
    if (widget.choice == PlanChoice.destination && _destination == null) {
      _error('Search and choose a destination.');
      return;
    }
    if (_rideLater && _scheduledFor == null) {
      _error('Choose the planned departure date and time.');
      return;
    }
    final value = double.tryParse(_target.text.trim());
    if (widget.choice == PlanChoice.loop && (value == null || value <= 0)) {
      _error('Enter a valid time or distance.');
      return;
    }
    Navigator.pop(
      context,
      _PlanRequest(
        choice: widget.choice,
        preference: _preference,
        prompt: widget.choice == PlanChoice.ai ? _prompt.text.trim() : null,
        destination: _destination,
        distanceKm: widget.choice == PlanChoice.loop && !_targetTime
            ? value
            : null,
        durationMinutes: widget.choice == PlanChoice.loop && _targetTime
            ? ((value ?? 1) * 60).round()
            : widget.choice == PlanChoice.surprise
            ? _surpriseMinutes
            : null,
        rideLater: _rideLater,
        scheduledFor: _rideLater ? _scheduledFor : null,
        headingDegrees: _heading,
        avoidHighways: _avoidHighways,
        avoidTolls: _avoidTolls,
      ),
    );
  }

  void _error(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              if (widget.choice == PlanChoice.ai) _aiQuestions(),
              if (widget.choice == PlanChoice.destination)
                _destinationQuestions(),
              if (widget.choice == PlanChoice.loop) _loopQuestions(),
              if (widget.choice == PlanChoice.surprise) _surpriseQuestions(),
              const SizedBox(height: 12),
              _timingQuestions(),
              const SizedBox(height: 12),
              _roadQuestions(),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Preview real routes',
                icon: Icons.alt_route_rounded,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aiQuestions() => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Describe your ideal journey',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _prompt,
          minLines: 4,
          maxLines: 7,
          decoration: const InputDecoration(
            hintText: 'A 3-hour scenic loop avoiding highways',
          ),
        ),
      ],
    ),
  );

  Widget _destinationQuestions() => Column(
    children: [
      if (_destination != null) ...[
        SurfaceCard(
          borderColor: MotoMapColors.primary,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.location_on_rounded,
              color: MotoMapColors.primary,
            ),
            title: Text(_destination!.name),
            subtitle: Text(
              _destination!.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Choose another location',
              onPressed: _chooseAnotherDestination,
              icon: const Icon(Icons.edit_location_alt_outlined),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      SurfaceCard(
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _findDestination(),
          decoration: InputDecoration(
            labelText: 'Where to?',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: IconButton(
              onPressed: _searching ? null : _findDestination,
              icon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
            ),
          ),
        ),
      ),
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 8),
        SurfaceCard(
          child: Column(
            children: [
              for (final result in _results.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _destination == result
                        ? Icons.check_circle
                        : Icons.location_on_outlined,
                    color: MotoMapColors.primary,
                  ),
                  title: Text(result.name),
                  subtitle: Text(
                    result.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => setState(() => _destination = result),
                ),
            ],
          ),
        ),
      ],
    ],
  );

  Future<void> _chooseAnotherDestination() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final selected = await Navigator.of(context).push<PlaceResult>(
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            currentLocation: MapPoint(position.latitude, position.longitude),
          ),
        ),
      );
      if (selected != null && mounted) {
        setState(() => _destination = selected);
      }
    } catch (error) {
      _error(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Widget _loopQuestions() => SurfaceCard(
    child: Column(
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Distance')),
            ButtonSegment(value: true, label: Text('Time')),
          ],
          selected: {_targetTime},
          onSelectionChanged: (value) => setState(() {
            _targetTime = value.first;
            _target.text = _targetTime ? '2' : '50';
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _targetTime ? 'Ride duration' : 'Loop distance',
            suffixText: _targetTime ? 'hours' : 'km',
          ),
        ),
      ],
    ),
  );

  Widget _surpriseQuestions() => Column(
    children: [
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How much time do you have?',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in [60, 120, 240, 480])
                  AppPill(
                    label: minutes == 480
                        ? 'Full day'
                        : '${minutes ~/ 60} hr${minutes == 60 ? '' : 's'}',
                    selected: _surpriseMinutes == minutes,
                    onTap: () => setState(() => _surpriseMinutes = minutes),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Heading',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in const [
                  ('Any', null),
                  ('N', 0.0),
                  ('E', 90.0),
                  ('S', 180.0),
                  ('W', 270.0),
                ])
                  AppPill(
                    label: item.$1,
                    selected: _heading == item.$2,
                    onTap: () => setState(() => _heading = item.$2),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _timingQuestions() => SurfaceCard(
    child: Column(
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Ride now')),
            ButtonSegment(value: true, label: Text('Ride later')),
          ],
          selected: {_rideLater},
          onSelectionChanged: (value) =>
              setState(() => _rideLater = value.first),
        ),
        if (_rideLater) ...[
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.event_outlined,
              color: MotoMapColors.primary,
            ),
            title: Text(
              _scheduledFor == null
                  ? 'Choose departure'
                  : _scheduledFor.toString().substring(0, 16),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _pickSchedule,
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Timing begins only when you press Start ride.',
            style: TextStyle(
              fontSize: 10,
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _roadQuestions() => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ROAD PREFERENCE', style: MotoMapText.labelCaps),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in RoutePreference.values)
              AppPill(
                label: item.label,
                selected: item == _preference,
                onTap: () => setState(() => _preference = item),
              ),
          ],
        ),
        const Divider(height: 24),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avoid highways'),
          value: _avoidHighways,
          onChanged: (value) => setState(() => _avoidHighways = value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avoid tolls'),
          value: _avoidTolls,
          onChanged: (value) => setState(() => _avoidTolls = value),
        ),
      ],
    ),
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
