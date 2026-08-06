import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/ride_data.dart';
import '../services/ride_repository.dart';
import '../services/routing_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'route_detail_screen.dart';

enum _PlanMode { destination, loop }

class PlanScreen extends StatefulWidget {
  const PlanScreen({required this.onOpenRides, super.key});

  final VoidCallback onOpenRides;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _promptController = TextEditingController();
  final _distanceController = TextEditingController(text: '50');
  _PlanMode _mode = _PlanMode.destination;
  RoutePreference _preference = RoutePreference.balanced;
  PlaceResult? _destination;
  bool _generating = false;
  RoutePlan? _generatedPlan;
  bool _requestingWebLocation = false;
  bool? _webLocationReady;
  String? _webLocationMessage;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestWebLocation();
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Future<MapPoint> _currentLocation() async {
    if (kIsWeb) return _webCurrentLocation();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Turn on Location Services to plan from your position.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is required for route planning.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return MapPoint(position.latitude, position.longitude);
    } on MissingPluginException {
      throw StateError(
        'The location component was not loaded. Fully close MotoMap and install '
        'the latest app build; hot reload cannot add a native plugin.',
      );
    }
  }

  Future<MapPoint> _webCurrentLocation() async {
    final uri = Uri.base;
    final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme != 'https' && !isLocalhost) {
      final message =
          'Safari can only ask for GPS permission from an HTTPS MotoMap '
          'address. The current ${uri.scheme}://${uri.host} address is not '
          'secure. Open an HTTPS deployment, then tap Enable location.';
      _setWebLocationState(ready: false, message: message);
      throw StateError(message);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: WebSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
          maximumAge: Duration(seconds: 10),
        ),
      );
      _setWebLocationState(
        ready: true,
        message: 'Location is enabled for route planning.',
      );
      return MapPoint(position.latitude, position.longitude);
    } on PermissionDeniedException {
      const message =
          'Location is blocked for this website. Change this site’s Location '
          'permission to Ask or Allow in Safari, then tap Enable location.';
      _setWebLocationState(ready: false, message: message);
      throw StateError(message);
    } on LocationServiceDisabledException {
      const message =
          'Location Services are disabled on this device. Turn them on, then '
          'tap Enable location.';
      _setWebLocationState(ready: false, message: message);
      throw StateError(message);
    } on TimeoutException {
      const message =
          'MotoMap did not receive a GPS position in time. Check Location '
          'Services and try Enable location again.';
      _setWebLocationState(ready: false, message: message);
      throw StateError(message);
    } on PositionUpdateException {
      const message =
          'The browser could not determine your position. Check Location '
          'Services and try Enable location again.';
      _setWebLocationState(ready: false, message: message);
      throw StateError(message);
    }
  }

  Future<void> _requestWebLocation() async {
    if (_requestingWebLocation) return;
    setState(() => _requestingWebLocation = true);
    try {
      await _webCurrentLocation();
    } catch (_) {
      // The location card contains the specific recovery action.
    } finally {
      if (mounted) setState(() => _requestingWebLocation = false);
    }
  }

  void _setWebLocationState({required bool ready, required String message}) {
    if (!mounted) return;
    setState(() {
      _webLocationReady = ready;
      _webLocationMessage = message;
    });
  }

  Future<void> _generateManual() async {
    if (_mode == _PlanMode.destination && _destination == null) {
      await _chooseDestination();
      if (_destination == null) return;
    }
    final requestedDistance = double.tryParse(_distanceController.text.trim());
    if (_mode == _PlanMode.loop &&
        (requestedDistance == null || requestedDistance < 3)) {
      _showError('Enter a loop distance of at least 3 km.');
      return;
    }
    await _generateAndSave(
      isLoop: _mode == _PlanMode.loop,
      destination: _destination,
      requestedDistanceKm: requestedDistance,
      preference: _preference,
      source: 'manual',
    );
  }

  Future<void> _generateSmart() async {
    final prompt = _promptController.text.trim();
    if (prompt.length < 5) {
      _showError('Describe the ride, destination, or loop distance first.');
      return;
    }
    final intent = RoutingService.instance.parsePrompt(prompt);
    final requestedDistance =
        intent.distanceKm ??
        (intent.durationMinutes == null
            ? null
            : intent.durationMinutes! / 60 * 45);
    PlaceResult? destination;
    if (!intent.isLoop) {
      final query = intent.destinationQuery;
      if (query == null) {
        _showError(
          'Include a destination using wording such as “ride to Tagaytay”.',
        );
        return;
      }
      setState(() => _generating = true);
      try {
        final origin = await _currentLocation();
        final results = await RoutingService.instance.searchPlaces(
          query,
          near: origin,
        );
        if (results.isEmpty) {
          throw StateError('No matching destination was found for “$query”.');
        }
        destination = results.first;
      } catch (error) {
        _showError(_friendlyError(error));
        if (mounted) setState(() => _generating = false);
        return;
      }
      if (mounted) setState(() => _generating = false);
    }
    await _generateAndSave(
      isLoop: intent.isLoop,
      destination: destination,
      requestedDistanceKm: requestedDistance ?? 50,
      requestedDurationMinutes: intent.durationMinutes,
      preference: intent.preference,
      source: 'smart_prompt',
      prompt: prompt,
    );
  }

  Future<void> _generateAndSave({
    required bool isLoop,
    required PlaceResult? destination,
    required double? requestedDistanceKm,
    required RoutePreference preference,
    required String source,
    String? prompt,
    int? requestedDurationMinutes,
  }) async {
    setState(() => _generating = true);
    try {
      final origin = await _currentLocation();
      final route = isLoop
          ? await RoutingService.instance.createLoop(
              origin: origin,
              requestedDistanceKm: requestedDistanceKm ?? 50,
              preference: preference,
            )
          : await RoutingService.instance.routeToDestination(
              origin: origin,
              destination: destination!.location,
              preference: preference,
            );
      final title = isLoop
          ? '${route.distanceKm.round()} km ${preference.label} Loop'
          : destination!.name;
      final saved = await RideRepository.instance.saveRoutePlan(
        route: route,
        title: title,
        source: source,
        prompt: prompt,
        originName: 'Current location',
        destinationName: isLoop ? 'Return to start' : destination!.displayName,
        isLoop: isLoop,
        preference: preference,
        requestedDistanceKm: isLoop ? requestedDistanceKm : null,
        requestedDurationMinutes: requestedDurationMinutes,
      );
      if (!mounted) return;
      setState(() {
        _generatedPlan = saved;
        _generating = false;
        _mode = isLoop ? _PlanMode.loop : _PlanMode.destination;
        _preference = preference;
        _destination = destination;
      });
    } catch (error) {
      if (mounted) setState(() => _generating = false);
      _showError(_friendlyError(error));
    }
  }

  Future<void> _chooseDestination() async {
    MapPoint? near;
    try {
      near = await _currentLocation();
    } catch (_) {
      near = null;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MotoMapColors.surfaceContainer,
      showDragHandle: true,
      builder: (context) => _DestinationSearch(near: near),
    );
    if (result != null && mounted) setState(() => _destination = result);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Plan a ride', style: MotoMapText.headlineLg),
              ),
              IconButton.filledTonal(
                onPressed: widget.onOpenRides,
                tooltip: 'Saved plans',
                icon: const Icon(Icons.bookmark_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Real roads, motorcycle routing, and voice-ready directions.',
            style: MotoMapText.bodyMd.copyWith(
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 14),
            SurfaceCard(
              color: _webLocationReady == true
                  ? MotoMapColors.success.withValues(alpha: 0.08)
                  : MotoMapColors.surfaceContainerLow,
              borderColor: _webLocationReady == true
                  ? MotoMapColors.success.withValues(alpha: 0.35)
                  : MotoMapColors.warning.withValues(alpha: 0.35),
              child: Row(
                children: [
                  Icon(
                    _webLocationReady == true
                        ? Icons.location_on_rounded
                        : Icons.location_off_outlined,
                    color: _webLocationReady == true
                        ? MotoMapColors.success
                        : MotoMapColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _webLocationReady == true
                              ? 'Location enabled'
                              : 'Location required',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _webLocationMessage ??
                              'MotoMap will ask for your location to plan from '
                                  'your current position.',
                          style: const TextStyle(
                            fontSize: 10,
                            color: MotoMapColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_webLocationReady != true) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _requestingWebLocation
                          ? null
                          : _requestWebLocation,
                      child: _requestingWebLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enable'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SurfaceCard(
            borderColor: MotoMapColors.primary.withValues(alpha: 0.28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: MotoMapColors.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Smart route planner',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AppPill(label: 'NO PAID API', compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try “80 km scenic loop” or “ride to Tagaytay using curvy roads”.',
                  style: TextStyle(
                    fontSize: 10,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promptController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _generating ? null : _generateSmart(),
                  decoration: const InputDecoration(
                    hintText:
                        'Describe destination, distance, time, and road style',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _generating ? null : _generateSmart,
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.alt_route_rounded),
                    label: Text(
                      _generating ? 'Building real route…' : 'Generate route',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            'Build it yourself',
            subtitle: 'Choose a destination or a loop distance',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              children: [
                SegmentedButton<_PlanMode>(
                  segments: const [
                    ButtonSegment(
                      value: _PlanMode.destination,
                      icon: Icon(Icons.location_on_outlined),
                      label: Text('Destination'),
                    ),
                    ButtonSegment(
                      value: _PlanMode.loop,
                      icon: Icon(Icons.loop_rounded),
                      label: Text('Loop ride'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) =>
                      setState(() => _mode = value.first),
                ),
                const SizedBox(height: 14),
                if (_mode == _PlanMode.destination)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.search_rounded,
                      color: MotoMapColors.primary,
                    ),
                    title: Text(
                      _destination?.name ?? 'Search destination',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      _destination?.displayName ??
                          'Search happens only when you submit, respecting the free geocoder policy.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _chooseDestination,
                  )
                else
                  TextField(
                    controller: _distanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Requested loop distance',
                      suffixText: 'km',
                      prefixIcon: Icon(Icons.route_rounded),
                    ),
                  ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ROAD STYLE', style: MotoMapText.labelCaps),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preference in RoutePreference.values)
                      AppPill(
                        label: preference.label,
                        selected: _preference == preference,
                        onTap: () => setState(() => _preference = preference),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _generating
                      ? 'Building route…'
                      : 'Preview and save route',
                  icon: Icons.map_outlined,
                  onPressed: _generating ? null : _generateManual,
                ),
              ],
            ),
          ),
          if (_generatedPlan != null) ...[
            const SizedBox(height: 16),
            SurfaceCard(
              color: const Color(0xFF14201B),
              borderColor: MotoMapColors.success.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROUTE SAVED',
                    style: TextStyle(
                      color: MotoMapColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _generatedPlan!.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_generatedPlan!.distanceKm.toStringAsFixed(1)} km · '
                    '${_formatDuration(_generatedPlan!.duration)} · '
                    '${_generatedPlan!.maneuvers.length} directions',
                    style: const TextStyle(
                      color: MotoMapColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Review route',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            RouteDetailScreen(plan: _generatedPlan!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }
}

class _DestinationSearch extends StatefulWidget {
  const _DestinationSearch({required this.near});

  final MapPoint? near;

  @override
  State<_DestinationSearch> createState() => _DestinationSearchState();
}

class _DestinationSearchState extends State<_DestinationSearch> {
  final _controller = TextEditingController();
  List<PlaceResult> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_controller.text.trim().length < 2) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await RoutingService.instance.searchPlaces(
        _controller.text,
        near: widget.near,
      );
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose destination', style: MotoMapText.headlineMd),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Place, landmark, or address',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Search data © OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 9,
                  color: MotoMapColors.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: MotoMapColors.error),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: _results.isEmpty
                    ? const Center(
                        child: Text(
                          'Submit a search to see real locations.',
                          style: TextStyle(
                            color: MotoMapColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: MotoMapColors.primary,
                            ),
                            title: Text(
                              result.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              result.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.pop(context, result),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
