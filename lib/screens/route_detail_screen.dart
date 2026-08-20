import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/motorcycle.dart';
import '../models/diagnostic_data.dart';
import '../models/ride_data.dart';
import '../models/shared_ride.dart';
import '../services/elm327_service.dart';
import '../services/motorcycle_service.dart';
import '../services/ride_repository.dart';
import '../services/routing_service.dart';
import '../services/shared_ride_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/motomap_map.dart';
import 'elm327_setup_screen.dart';
import 'location_picker_screen.dart';
import 'ride_mode_screen.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    this.plan,
    this.alternatives = const [],
    this.sharedRide,
    this.title,
    this.distance,
    this.duration,
    this.elevation,
    this.variant,
    super.key,
  });

  final RoutePlan? plan;
  final List<RouteAlternative> alternatives;
  final SharedRide? sharedRide;
  final String? title;
  final String? distance;
  final String? duration;
  final String? elevation;
  final int? variant;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  late RoutePlan _plan;
  late List<RouteAlternative> _alternatives;
  late Future<List<Motorcycle>> _motorcycles;
  SharedRide? _sharedRide;
  Motorcycle? _selectedBike;
  int _selectedAlternative = 0;
  bool _saving = false;
  bool _checkingBike = false;
  int _previewTab = 0;
  MapLibreMapController? _mapController;
  Timer? _groupRefreshTimer;

  bool get _ownsPlan =>
      _plan.userId == Supabase.instance.client.auth.currentUser?.id;

  SharedRideMember? get _currentGroupMember {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _sharedRide == null) return null;
    return _sharedRide!.members.cast<SharedRideMember?>().firstWhere(
      (member) => member?.userId == userId && member?.status == 'joined',
      orElse: () => null,
    );
  }

  bool get _startEnabled {
    final shared = _sharedRide;
    if (shared == null || shared.hasStarted) return true;
    final member = _currentGroupMember;
    return member?.isLeader == true && shared.everyoneReady;
  }

  String get _startLabel {
    final shared = _sharedRide;
    if (shared == null) {
      return _plan.departureMode == 'later'
          ? 'Start ride when ready'
          : 'Start ride';
    }
    if (shared.hasStarted) return 'Join active ride';
    if (_currentGroupMember?.isLeader != true) return 'Waiting for leader';
    if (!shared.everyoneReady) return 'Waiting for every rider';
    return 'Start group ride';
  }

  @override
  void initState() {
    super.initState();
    if (widget.plan == null) return;
    _plan = widget.plan!;
    _alternatives = widget.alternatives.isEmpty
        ? [
            RouteAlternative(
              route: _generatedFromPlan(_plan),
              preference: _plan.preference,
              label: 'Saved route',
            ),
          ]
        : List.of(widget.alternatives);
    _sharedRide = widget.sharedRide;
    _motorcycles = MotorcycleService.instance.fetchMotorcycles();
    Elm327Service.instance.addListener(_elmChanged);
    _loadPreviewData();
  }

  @override
  void dispose() {
    if (widget.plan != null) {
      Elm327Service.instance.removeListener(_elmChanged);
    }
    _groupRefreshTimer?.cancel();
    super.dispose();
  }

  void _elmChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPreviewData() async {
    try {
      final bikes = await _motorcycles;
      _selectedBike = bikes.cast<Motorcycle?>().firstWhere(
        (bike) => bike?.id == _plan.motorcycleId,
        orElse: () => bikes.isEmpty ? null : bikes.first,
      );
      _sharedRide ??= await SharedRideService.instance.fetchForRoute(_plan.id);
      _startGroupRefreshIfNeeded();
      if (mounted) setState(() {});
    } catch (_) {
      // Each tab still renders its own recovery controls.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plan == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? 'Route preview')),
        body: const Center(
          child: Text('This preview has no saved road geometry.'),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MotoMapView(
              route: _plan.coordinates,
              markers: _plan.waypoints
                  .map((waypoint) => waypoint.location)
                  .toList(growable: false),
              onMapLongPress: _ownsPlan ? _handleMapTap : null,
              onControllerReady: (controller) => _mapController = controller,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton.filled(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: MotoMapColors.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _plan.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${_plan.distanceKm.toStringAsFixed(1)} km · ${_duration(_plan.duration)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: MotoMapColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: MediaQuery.paddingOf(context).top + 86,
            child: IconButton.filled(
              tooltip: 'Recenter route',
              onPressed: _recenterRoute,
              icon: const Icon(Icons.my_location_rounded),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.46,
            minChildSize: 0.22,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.22, 0.46, 0.92],
            builder: (context, scrollController) =>
                _directionsSheet(scrollController),
          ),
          if (_saving)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Color(0x55000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _directionsSheet(ScrollController controller) => DecoratedBox(
    decoration: const BoxDecoration(
      color: MotoMapColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24)],
    ),
    child: Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: MotoMapColors.outlineVariant,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Motorcycle directions',
                  style: MotoMapText.headlineMd,
                ),
              ),
              IconButton(
                tooltip: 'Close preview',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _previewTabs(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (_previewTab) {
            1 => ListView(
              controller: controller,
              padding: const EdgeInsets.only(bottom: 16),
              children: [SizedBox(height: 650, child: _motorcycleTab())],
            ),
            2 => ListView(
              controller: controller,
              padding: const EdgeInsets.only(bottom: 16),
              children: [SizedBox(height: 620, child: _groupTab())],
            ),
            _ => _detailsPreview(controller),
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: PrimaryButton(
            label: _startLabel,
            icon: Icons.navigation_rounded,
            onPressed: _saving || !_startEnabled ? null : _prepareStart,
          ),
        ),
      ],
    ),
  );

  Widget _previewTabs() => SurfaceCard(
    padding: const EdgeInsets.all(5),
    child: Row(
      children: [
        _PreviewTab(
          icon: Icons.tune_rounded,
          label: 'Details',
          selected: _previewTab == 0,
          onTap: () => setState(() => _previewTab = 0),
        ),
        _PreviewTab(
          icon: Icons.two_wheeler_rounded,
          label: 'Motorcycle',
          selected: _previewTab == 1,
          onTap: () => setState(() => _previewTab = 1),
        ),
        _PreviewTab(
          icon: Icons.groups_2_rounded,
          label: 'Group',
          selected: _previewTab == 2,
          onTap: () => setState(() => _previewTab = 2),
        ),
      ],
    ),
  );

  Widget _detailsPreview(ScrollController controller) => ListView(
    controller: controller,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
    children: [
      SurfaceCard(
        child: Column(
          children: [
            _WaypointRow(
              icon: Icons.my_location_rounded,
              title: _plan.originName,
              subtitle: 'Start',
              onTap: _ownsPlan ? _changeOrigin : null,
            ),
            for (var index = 0; index < _plan.waypoints.length; index++)
              _WaypointRow(
                icon: Icons.add_location_alt_outlined,
                title: _plan.waypoints[index].name,
                subtitle: 'Stop ${index + 1}',
                onRemove: _ownsPlan ? () => _removeStop(index) : null,
              ),
            _WaypointRow(
              icon: Icons.location_on_rounded,
              title: _plan.destinationName,
              subtitle: 'Destination',
              onTap: _ownsPlan ? _changeDestination : null,
            ),
            if (_ownsPlan)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addStop,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add stop'),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          AppPill(
            label: _plan.departureMode == 'later' ? 'Later' : 'Now',
            selected: true,
          ),
          const SizedBox(width: 8),
          AppPill(
            label: _plan.avoidHighways || _plan.avoidTolls
                ? 'Avoid enabled'
                : 'No avoids',
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text('ROUTE OPTIONS', style: MotoMapText.labelCaps),
      const SizedBox(height: 8),
      for (var index = 0; index < _alternatives.length; index++) ...[
        _AlternativeCard(
          alternative: _alternatives[index],
          selected: index == _selectedAlternative,
          onTap: _ownsPlan ? () => _chooseAlternative(index) : null,
        ),
        const SizedBox(height: 8),
      ],
      if (_alternatives.length == 1)
        const Text(
          'No meaningfully different route is available for the selected stops and preferences.',
          style: TextStyle(fontSize: 10, color: MotoMapColors.onSurfaceVariant),
        ),
      const SizedBox(height: 8),
      SizedBox(height: 610, child: _detailsTab()),
    ],
  );

  Widget _detailsTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
    children: [
      Row(
        children: [
          Expanded(
            child: _Metric(
              label: 'DISTANCE',
              value: '${_plan.distanceKm.toStringAsFixed(1)} km',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Metric(
              label: 'ESTIMATED TIME',
              value: _duration(_plan.duration),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ROUTE CHARACTER', style: MotoMapText.labelCaps),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preference in RoutePreference.values)
                  AppPill(
                    label: preference.label,
                    selected: _plan.preference == preference,
                    onTap: _ownsPlan
                        ? () => _changePreference(preference)
                        : null,
                  ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avoid highways'),
              value: _plan.avoidHighways,
              onChanged: _ownsPlan
                  ? (value) => _reroute(avoidHighways: value)
                  : null,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avoid tolls'),
              value: _plan.avoidTolls,
              onChanged: _ownsPlan
                  ? (value) => _reroute(avoidTolls: value)
                  : null,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SectionHeader(
        'Stops',
        subtitle: _ownsPlan
            ? 'Search stops or pin a new endpoint on the Map tab'
            : 'Stops chosen by the ride leader',
        action: _ownsPlan ? 'ADD STOP' : null,
        onAction: _ownsPlan ? _addStop : null,
      ),
      const SizedBox(height: 8),
      SurfaceCard(
        child: Column(
          children: [
            _WaypointRow(
              icon: Icons.radio_button_checked,
              title: _plan.originName,
              subtitle: 'Start',
            ),
            for (var index = 0; index < _plan.waypoints.length; index++)
              _WaypointRow(
                icon: Icons.more_vert_rounded,
                title: _plan.waypoints[index].name,
                subtitle: 'Stop ${index + 1}',
                onRemove: _ownsPlan ? () => _removeStop(index) : null,
              ),
            _WaypointRow(
              icon: Icons.location_on_rounded,
              title: _plan.destinationName,
              subtitle: 'Destination',
            ),
          ],
        ),
      ),
      if (_plan.scheduledFor != null) ...[
        const SizedBox(height: 12),
        SurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.event_outlined,
              color: MotoMapColors.primary,
            ),
            title: const Text('Ride later'),
            subtitle: Text(_plan.scheduledFor!.toLocal().toString()),
          ),
        ),
      ],
    ],
  );

  Widget _motorcycleTab() => FutureBuilder<List<Motorcycle>>(
    future: _motorcycles,
    builder: (context, snapshot) {
      final bikes = snapshot.data ?? const [];
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (bikes.isEmpty) {
        return const Center(
          child: Text('Add a motorcycle in Rides → Garage first.'),
        );
      }
      _selectedBike ??= bikes.first;
      final elm = Elm327Service.instance;
      final sameBike = elm.motorcycle?.id == _selectedBike!.id;
      final adapterOnline = sameBike && elm.adapterConnected;
      final ecuOnline = sameBike && elm.ecuAvailable;
      final health = ecuOnline ? elm.evaluateCurrentHealth() : null;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedBike!.id,
            decoration: const InputDecoration(
              labelText: 'Motorcycle for this ride',
              prefixIcon: Icon(Icons.two_wheeler_outlined),
            ),
            items: [
              for (final bike in bikes)
                DropdownMenuItem(value: bike.id, child: Text(bike.displayName)),
            ],
            onChanged: (id) =>
                _selectBike(bikes.firstWhere((bike) => bike.id == id)),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            borderColor: ecuOnline
                ? MotoMapColors.success.withValues(alpha: 0.45)
                : MotoMapColors.warning.withValues(alpha: 0.45),
            child: Column(
              children: [
                _ConnectionLine(
                  label: 'ELM327 adapter',
                  connected: adapterOnline,
                ),
                const Divider(height: 22),
                _ConnectionLine(label: 'Motorcycle ECU', connected: ecuOnline),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: adapterOnline ? 'Retry / reconnect' : 'Connect ELM327',
                  icon: Icons.bluetooth_connected_rounded,
                  onPressed: _connectBike,
                ),
                if (ecuOnline) ...[
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: _checkingBike
                        ? 'Checking motorcycle…'
                        : 'Run pre-ride bike check',
                    secondary: true,
                    icon: Icons.health_and_safety_outlined,
                    onPressed: _checkingBike ? null : _runPreRideCheck,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRE-RIDE BIKE CHECK',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (!ecuOnline)
                  const Text(
                    'Connect the ECU to preview supported fault codes and dangers. The ride can still use GPS without telemetry.',
                    style: TextStyle(color: MotoMapColors.onSurfaceVariant),
                  )
                else if (health!.$2.isEmpty)
                  const _HealthLine(
                    icon: Icons.check_circle_outline,
                    text: 'No danger found in supported ECU data',
                    color: MotoMapColors.success,
                  )
                else
                  for (final issue in health.$2)
                    _HealthLine(
                      icon: Icons.warning_amber_rounded,
                      text: issue,
                      color: MotoMapColors.warning,
                    ),
                if (ecuOnline && elm.latestTroubleCodes.isNotEmpty) ...[
                  const Divider(height: 22),
                  for (final code in elm.latestTroubleCodes)
                    Text(
                      '${code.code} · ${code.description}',
                      style: const TextStyle(
                        color: MotoMapColors.error,
                        fontSize: 10,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _groupTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
    children: [
      if (_sharedRide == null)
        SurfaceCard(
          child: Column(
            children: [
              const Icon(
                Icons.groups_2_outlined,
                size: 42,
                color: MotoMapColors.primary,
              ),
              const SizedBox(height: 10),
              const Text(
                'Create a shared ride',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'MotoMap will generate a private six-character code. Only riders who join with it can see this group.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MotoMapColors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Generate group code',
                icon: Icons.key_rounded,
                onPressed: _saving ? null : _createSharedRide,
              ),
            ],
          ),
        )
      else ...[
        SurfaceCard(
          borderColor: MotoMapColors.primary.withValues(alpha: 0.5),
          child: Column(
            children: [
              const Text(
                'PRIVATE RIDE CODE',
                style: TextStyle(
                  fontSize: 9,
                  color: MotoMapColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _sharedRide!.joinCode,
                style: const TextStyle(
                  fontSize: 30,
                  letterSpacing: 7,
                  fontWeight: FontWeight.w900,
                  color: MotoMapColors.primary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _sharedRide!.joinCode));
                  _message('Ride code copied.');
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy code'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionHeader(
          'Riders',
          subtitle:
              '${_sharedRide!.joinedMembers.length} joined · ${_sharedRide!.joinedMembers.where((member) => member.isReady).length} ready',
          action: 'REFRESH',
          onAction: _refreshSharedRide,
        ),
        const SizedBox(height: 8),
        for (final member in _sharedRide!.joinedMembers) ...[
          SurfaceCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: MotoMapColors.primary.withValues(alpha: 0.15),
                child: Text(member.riderName.characters.first),
              ),
              title: Text(member.riderName),
              subtitle: Text(member.motorcycleName ?? 'No motorcycle selected'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (member.isLeader)
                    const Text(
                      'LEADER',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  Text(
                    member.isReady ? 'READY' : 'NOT READY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: member.isReady
                          ? MotoMapColors.success
                          : MotoMapColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_currentGroupMember != null && !_sharedRide!.hasStarted) ...[
          PrimaryButton(
            label: _currentGroupMember!.isReady
                ? 'Mark not ready'
                : 'I am ready',
            icon: _currentGroupMember!.isReady
                ? Icons.close_rounded
                : Icons.check_circle_rounded,
            secondary: _currentGroupMember!.isReady,
            onPressed: _saving ? null : _toggleReady,
          ),
          const SizedBox(height: 10),
        ],
        SurfaceCard(
          child: Text(
            _sharedRide!.hasStarted
                ? 'The leader started this ride. Joined riders can now enter the live ride view.'
                : 'Every joined rider, including the leader, must be Ready before the leader can start.',
            style: const TextStyle(
              fontSize: 10,
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ],
  );

  Future<void> _chooseAlternative(int index) async {
    final alternative = _alternatives[index];
    await _saveRoute(
      route: alternative.route,
      preference: alternative.preference,
    );
    if (mounted) setState(() => _selectedAlternative = index);
  }

  Future<void> _changePreference(RoutePreference preference) async {
    await _reroute(preference: preference);
  }

  Future<void> _reroute({
    RoutePreference? preference,
    bool? avoidHighways,
    bool? avoidTolls,
    List<RouteWaypoint>? waypoints,
    MapPoint? origin,
    String? originName,
    MapPoint? destination,
    String? destinationName,
  }) async {
    setState(() => _saving = true);
    try {
      final selectedPreference = preference ?? _plan.preference;
      final selectedStops = waypoints ?? _plan.waypoints;
      final route = await RoutingService.instance.routeToDestination(
        origin: origin ?? _plan.origin,
        destination: destination ?? _plan.destination,
        preference: selectedPreference,
        waypoints: selectedStops,
        avoidHighways: avoidHighways ?? _plan.avoidHighways,
        avoidTolls: avoidTolls ?? _plan.avoidTolls,
      );
      await _saveRoute(
        route: route,
        preference: selectedPreference,
        waypoints: selectedStops,
        avoidHighways: avoidHighways,
        avoidTolls: avoidTolls,
        originName: originName,
        destinationName: destinationName,
      );
      _alternatives = [
        RouteAlternative(
          route: route,
          preference: selectedPreference,
          label: 'Customized',
        ),
      ];
      _selectedAlternative = 0;
    } catch (error) {
      _message('Could not update route: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveRoute({
    required GeneratedRoute route,
    required RoutePreference preference,
    List<RouteWaypoint>? waypoints,
    bool? avoidHighways,
    bool? avoidTolls,
    String? motorcycleId,
    String? originName,
    String? destinationName,
  }) async {
    final saved = await RideRepository.instance.updateRoutePlan(
      _plan,
      route: route,
      preference: preference,
      waypoints: waypoints ?? _plan.waypoints,
      avoidHighways: avoidHighways ?? _plan.avoidHighways,
      avoidTolls: avoidTolls ?? _plan.avoidTolls,
      motorcycleId: motorcycleId ?? _plan.motorcycleId,
      originName: originName,
      destinationName: destinationName,
    );
    if (mounted) setState(() => _plan = saved);
  }

  Future<void> _handleMapTap(MapPoint point) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this map pin'),
        content: const Text(
          'Add it as an ordered stop or make it the ride endpoint. MotoMap will rebuild the real road route.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'stop'),
            child: const Text('Add stop'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'endpoint'),
            child: const Text('Set endpoint'),
          ),
        ],
      ),
    );
    if (action == 'stop') {
      await _reroute(
        waypoints: [
          ..._plan.waypoints,
          RouteWaypoint(
            name: 'Pinned stop ${_plan.waypoints.length + 1}',
            location: point,
          ),
        ],
      );
    } else if (action == 'endpoint') {
      await _reroute(destination: point, destinationName: 'Pinned destination');
    }
  }

  Future<void> _addStop() async {
    final place = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(currentLocation: _plan.origin),
      ),
    );
    if (place != null) {
      await _reroute(
        waypoints: [
          ..._plan.waypoints,
          RouteWaypoint(name: place.name, location: place.location),
        ],
      );
    }
  }

  Future<void> _changeOrigin() async {
    final place = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(currentLocation: _plan.origin),
      ),
    );
    if (place != null) {
      await _reroute(origin: place.location, originName: place.name);
    }
  }

  Future<void> _changeDestination() async {
    final place = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(currentLocation: _plan.origin),
      ),
    );
    if (place != null) {
      await _reroute(destination: place.location, destinationName: place.name);
    }
  }

  Future<void> _recenterRoute() async {
    if (_plan.coordinates.isEmpty) return;
    final point = _plan.coordinates.first;
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), 14),
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _removeStop(int index) async {
    final stops = List<RouteWaypoint>.of(_plan.waypoints)..removeAt(index);
    await _reroute(waypoints: stops);
  }

  Future<void> _selectBike(Motorcycle bike) async {
    setState(() => _selectedBike = bike);
    if (_ownsPlan) {
      await _saveRoute(
        route: _generatedFromPlan(_plan),
        preference: _plan.preference,
        motorcycleId: bike.id,
      );
    }
    if (_sharedRide != null) {
      final refreshed = await SharedRideService.instance.selectMotorcycle(
        sharedRideId: _sharedRide!.id,
        motorcycleId: bike.id,
      );
      if (mounted) setState(() => _sharedRide = refreshed);
    }
  }

  Future<void> _connectBike() async {
    final bike = _selectedBike;
    if (bike == null) return;
    try {
      if (bike.hasElmAdapter) {
        await Elm327Service.instance.reconnectToMotorcycle(bike);
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Elm327SetupScreen(motorcycle: bike),
          ),
        );
        final refreshed = await MotorcycleService.instance.fetchMotorcycle(
          bike.id,
        );
        if (mounted) setState(() => _selectedBike = refreshed);
      }
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _runPreRideCheck() async {
    setState(() => _checkingBike = true);
    try {
      await Elm327Service.instance.runDiagnostic(
        type: DiagnosticSessionType.preRide,
      );
      if (mounted) setState(() {});
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _checkingBike = false);
    }
  }

  Future<void> _createSharedRide() async {
    setState(() => _saving = true);
    try {
      final shared = await SharedRideService.instance.create(
        routePlanId: _plan.id,
        motorcycleId: _selectedBike?.id,
      );
      if (mounted) setState(() => _sharedRide = shared);
      _startGroupRefreshIfNeeded();
    } catch (error) {
      _message('Could not create shared ride: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refreshSharedRide() async {
    final shared = _sharedRide;
    if (shared == null) return;
    try {
      final refreshed = await SharedRideService.instance.fetch(shared.id);
      if (mounted) setState(() => _sharedRide = refreshed);
    } catch (error) {
      _message('Could not refresh riders: $error');
    }
  }

  void _startGroupRefreshIfNeeded() {
    if (_sharedRide == null || _groupRefreshTimer != null) return;
    _groupRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final shared = _sharedRide;
      if (!mounted || shared == null) return;
      try {
        final refreshed = await SharedRideService.instance.fetch(shared.id);
        if (mounted) setState(() => _sharedRide = refreshed);
      } catch (_) {
        // Manual refresh remains available when the connection is interrupted.
      }
    });
  }

  Future<void> _toggleReady() async {
    final shared = _sharedRide;
    final member = _currentGroupMember;
    if (shared == null || member == null) return;
    setState(() => _saving = true);
    try {
      final refreshed = await SharedRideService.instance.setReady(
        sharedRideId: shared.id,
        isReady: !member.isReady,
      );
      if (mounted) setState(() => _sharedRide = refreshed);
    } catch (error) {
      _message('Could not update readiness: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _prepareStart() async {
    final elm = Elm327Service.instance;
    final bike = _selectedBike;
    final ready =
        bike != null &&
        elm.motorcycle?.id == bike.id &&
        elm.adapterConnected &&
        elm.ecuAvailable;
    if (ready) {
      await _startGroupAndOpen();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bluetooth_disabled_rounded,
              size: 42,
              color: MotoMapColors.warning,
            ),
            const SizedBox(height: 10),
            const Text(
              'Connect for a better ride?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'ELM327 and ECU telemetry are optional. Connecting enables supported fault warnings and live motorcycle readings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MotoMapColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Connect / reconnect',
              icon: Icons.bluetooth_connected_rounded,
              onPressed: () {
                Navigator.pop(context);
                _connectBike();
              },
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Start with GPS only',
              secondary: true,
              onPressed: () {
                Navigator.pop(context);
                _startGroupAndOpen();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGroupAndOpen() async {
    final shared = _sharedRide;
    if (shared != null && !shared.hasStarted) {
      setState(() => _saving = true);
      try {
        final started = await SharedRideService.instance.start(shared.id);
        if (!mounted) return;
        setState(() => _sharedRide = started);
      } catch (error) {
        _message('Everyone must be ready before the leader can start. $error');
        if (mounted) setState(() => _previewTab = 2);
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    if (mounted) await _openRideMode();
  }

  Future<void> _openRideMode() async {
    final ridePlan = _selectedBike == null
        ? _plan
        : _plan.copyWithRoute(
            route: _generatedFromPlan(_plan),
            motorcycleId: _selectedBike!.id,
          );
    final completed = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideModeScreen(plan: ridePlan, sharedRide: _sharedRide),
      ),
    );
    if (completed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static GeneratedRoute _generatedFromPlan(RoutePlan plan) => GeneratedRoute(
    origin: plan.origin,
    destination: plan.destination,
    distanceKm: plan.distanceKm,
    durationSeconds: plan.durationSeconds,
    coordinates: plan.coordinates,
    maneuvers: plan.maneuvers,
  );

  static String _duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }
}

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({
    required this.alternative,
    required this.selected,
    required this.onTap,
  });
  final RouteAlternative alternative;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    borderColor: selected
        ? MotoMapColors.primary
        : MotoMapColors.outlineVariant,
    child: Row(
      children: [
        Icon(
          selected ? Icons.check_circle : Icons.alt_route_rounded,
          color: selected
              ? MotoMapColors.primary
              : MotoMapColors.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alternative.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '${alternative.route.distanceKm.toStringAsFixed(1)} km · ${_RouteDetailScreenState._duration(Duration(seconds: alternative.route.durationSeconds))} · ${alternative.preference.label}',
                style: const TextStyle(
                  fontSize: 9,
                  color: MotoMapColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
      ],
    ),
  );
}

class _WaypointRow extends StatelessWidget {
  const _WaypointRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRemove,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: MotoMapColors.primary),
    title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(subtitle),
    trailing: onRemove == null
        ? null
        : IconButton(
            tooltip: 'Remove stop',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
  );
}

class _PreviewTab extends StatelessWidget {
  const _PreviewTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? MotoMapColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? MotoMapColors.primary
                  : MotoMapColors.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: selected
                    ? MotoMapColors.primary
                    : MotoMapColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine({required this.label, required this.connected});
  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        connected ? Icons.check_circle : Icons.cancel_outlined,
        color: connected ? MotoMapColors.success : MotoMapColors.warning,
      ),
      const SizedBox(width: 9),
      Expanded(child: Text(label)),
      Text(
        connected ? 'CONNECTED' : 'NOT CONNECTED',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: connected ? MotoMapColors.success : MotoMapColors.warning,
        ),
      ),
    ],
  );
}

class _HealthLine extends StatelessWidget {
  const _HealthLine({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
