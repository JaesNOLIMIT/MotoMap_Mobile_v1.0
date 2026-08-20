import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/ride_data.dart';
import '../services/routing_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/motomap_map.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({required this.currentLocation, super.key});

  final MapPoint currentLocation;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  MapLibreMapController? _mapController;
  List<PlaceResult> _results = const [];
  PlaceResult? _selected;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search([String? category]) async {
    final query = (category ?? _searchController.text).trim();
    if (query.length < 2) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _searching = true);
    try {
      final results = await RoutingService.instance.searchPlaces(
        query,
        near: widget.currentLocation,
      );
      if (mounted) setState(() => _results = results);
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pin(MapPoint point) async {
    setState(() {
      _selected = PlaceResult(
        name: 'Pinned location',
        displayName:
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        location: point,
      );
    });
    try {
      final place = await RoutingService.instance.reverseGeocode(point);
      if (mounted) setState(() => _selected = place);
    } catch (_) {
      // Coordinates remain usable even if reverse geocoding is unavailable.
    }
  }

  Future<void> _select(PlaceResult place) async {
    setState(() => _selected = place);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(place.location.latitude, place.location.longitude),
        16,
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MotoMapView(
              route: const [],
              currentLocation: widget.currentLocation,
              markers: _selected == null ? const [] : [_selected!.location],
              onMapLongPress: _pin,
              onControllerReady: (controller) => _mapController = controller,
            ),
          ),
          SafeArea(
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
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Search a place or address',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Search',
                          onPressed: _searching ? null : _search,
                          icon: _searching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: MediaQuery.paddingOf(context).top + 72,
            child: IconButton.filled(
              tooltip: 'Recenter on me',
              onPressed: () => _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(
                    widget.currentLocation.latitude,
                    widget.currentLocation.longitude,
                  ),
                  15,
                ),
                duration: const Duration(milliseconds: 500),
              ),
              icon: const Icon(Icons.my_location_rounded),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.34,
            minChildSize: 0.22,
            maxChildSize: 0.76,
            snap: true,
            snapSizes: const [0.34, 0.76],
            builder: (context, controller) => DecoratedBox(
              decoration: const BoxDecoration(
                color: MotoMapColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20)],
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: MotoMapColors.outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Choose destination', style: MotoMapText.headlineMd),
                  const SizedBox(height: 4),
                  const Text(
                    'Search, choose a nearby place, or long-press anywhere on the map to drop a pin.',
                    style: TextStyle(color: MotoMapColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 78,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _NearbyChoice(
                          'Fuel',
                          Icons.local_gas_station_rounded,
                          () => _search('fuel station'),
                        ),
                        _NearbyChoice(
                          'Food',
                          Icons.restaurant_rounded,
                          () => _search('restaurant'),
                        ),
                        _NearbyChoice(
                          'Coffee',
                          Icons.local_cafe_rounded,
                          () => _search('cafe'),
                        ),
                        _NearbyChoice(
                          'Shop',
                          Icons.storefront_rounded,
                          () => _search('shop'),
                        ),
                        _NearbyChoice(
                          'Scenic',
                          Icons.landscape_rounded,
                          () => _search('viewpoint'),
                        ),
                      ],
                    ),
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: 10),
                    SurfaceCard(
                      borderColor: MotoMapColors.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selected!.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selected!.displayName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: MotoMapColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Use this destination',
                            icon: Icons.location_on_rounded,
                            onPressed: () => Navigator.pop(context, _selected),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('SEARCH RESULTS', style: MotoMapText.labelCaps),
                    for (final result in _results)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: MotoMapColors.primary,
                        ),
                        title: Text(result.name),
                        subtitle: Text(
                          result.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _select(result),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyChoice extends StatelessWidget {
  const _NearbyChoice(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: MotoMapColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MotoMapColors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: MotoMapColors.primary),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}
