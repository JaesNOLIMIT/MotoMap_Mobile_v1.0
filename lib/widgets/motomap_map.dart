import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../config/map_config.dart';
import '../models/ride_data.dart';
import '../theme/motomap_colors.dart';

class MotoMapView extends StatefulWidget {
  const MotoMapView({
    required this.route,
    this.traveled = const [],
    this.currentLocation,
    this.followLocation = false,
    this.followBearing = false,
    this.interactive = true,
    this.markers = const [],
    this.onMapTap,
    this.onMapLongPress,
    this.onControllerReady,
    this.onTrackingDismissed,
    super.key,
  });

  final List<MapPoint> route;
  final List<MapPoint> traveled;
  final MapPoint? currentLocation;
  final bool followLocation;
  final bool followBearing;
  final bool interactive;
  final List<MapPoint> markers;
  final ValueChanged<MapPoint>? onMapTap;
  final ValueChanged<MapPoint>? onMapLongPress;
  final ValueChanged<MapLibreMapController>? onControllerReady;
  final VoidCallback? onTrackingDismissed;

  @override
  State<MotoMapView> createState() => _MotoMapViewState();
}

class _MotoMapViewState extends State<MotoMapView> {
  MapLibreMapController? _controller;
  Line? _routeLine;
  Line? _traveledLine;
  Circle? _destinationCircle;
  final List<Circle> _markerCircles = [];
  final List<Symbol> _directionSymbols = [];
  bool _styleLoaded = false;

  MapPoint get _initialPoint =>
      widget.currentLocation ??
      (widget.route.isEmpty
          ? const MapPoint(14.5995, 120.9842)
          : widget.route.first);

  @override
  void didUpdateWidget(covariant MotoMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded &&
        (oldWidget.route != widget.route ||
            oldWidget.traveled.length != widget.traveled.length ||
            oldWidget.markers != widget.markers)) {
      unawaited(_drawLines());
    }
    if (widget.followLocation &&
        widget.currentLocation != null &&
        oldWidget.currentLocation != widget.currentLocation) {
      unawaited(centerOn(widget.currentLocation!, zoom: 16));
    }
  }

  Future<void> centerOn(MapPoint point, {double zoom = 15}) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(_latLng(point), zoom),
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> zoomBy(double amount) async {
    await _controller?.animateCamera(CameraUpdate.zoomBy(amount));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: MotoMapColors.surfaceContainer,
        child: MapLibreMap(
          styleString: MapConfig.styleUrl,
          initialCameraPosition: CameraPosition(
            target: _latLng(_initialPoint),
            zoom: widget.route.isEmpty ? 11 : 13,
          ),
          onMapCreated: (controller) {
            _controller = controller;
            widget.onControllerReady?.call(controller);
          },
          onCameraTrackingDismissed: widget.onTrackingDismissed,
          onMapClick: widget.onMapTap == null
              ? null
              : (_, point) =>
                    widget.onMapTap!(MapPoint(point.latitude, point.longitude)),
          onMapLongClick: widget.onMapLongPress == null
              ? null
              : (_, point) => widget.onMapLongPress!(
                  MapPoint(point.latitude, point.longitude),
                ),
          onStyleLoadedCallback: () {
            _styleLoaded = true;
            unawaited(_drawLines());
            if (!widget.followLocation) unawaited(_fitRoute());
          },
          myLocationEnabled:
              widget.followLocation || widget.currentLocation != null,
          myLocationTrackingMode: widget.followLocation
              ? widget.followBearing
                    ? MyLocationTrackingMode.trackingCompass
                    : MyLocationTrackingMode.trackingGps
              : MyLocationTrackingMode.none,
          compassEnabled: true,
          rotateGesturesEnabled: widget.interactive,
          scrollGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
        ),
      ),
    );
  }

  Future<void> _drawLines() async {
    final controller = _controller;
    if (!_styleLoaded || controller == null) return;
    if (_routeLine != null) {
      await controller.removeLine(_routeLine!);
      _routeLine = null;
    }
    if (_traveledLine != null) {
      await controller.removeLine(_traveledLine!);
      _traveledLine = null;
    }
    if (_destinationCircle != null) {
      await controller.removeCircle(_destinationCircle!);
      _destinationCircle = null;
    }
    if (_markerCircles.isNotEmpty) {
      await controller.removeCircles(_markerCircles);
      _markerCircles.clear();
    }
    if (_directionSymbols.isNotEmpty) {
      await controller.removeSymbols(_directionSymbols);
      _directionSymbols.clear();
    }
    if (widget.route.length >= 2) {
      _routeLine = await controller.addLine(
        LineOptions(
          geometry: widget.route.map(_latLng).toList(growable: false),
          lineColor: '#FF673D',
          lineWidth: 5,
          lineOpacity: 0.88,
          lineJoin: 'round',
        ),
      );
      _destinationCircle = await controller.addCircle(
        CircleOptions(
          geometry: _latLng(widget.route.last),
          circleColor: '#FF673D',
          circleRadius: 7,
          circleStrokeColor: '#FFF4EF',
          circleStrokeWidth: 2,
        ),
      );
      final step = math.max(8, widget.route.length ~/ 12);
      for (var index = step; index < widget.route.length - 1; index += step) {
        final point = widget.route[index];
        final next = widget.route[index + 1];
        _directionSymbols.add(
          await controller.addSymbol(
            SymbolOptions(
              geometry: _latLng(point),
              textField: '➤',
              textSize: 15,
              textRotate: _bearing(point, next) - 90,
              textColor: '#FFF4EF',
              textHaloColor: '#FF673D',
              textHaloWidth: 2.5,
            ),
          ),
        );
      }
    }
    for (final marker in widget.markers) {
      _markerCircles.add(
        await controller.addCircle(
          CircleOptions(
            geometry: _latLng(marker),
            circleColor: '#FFD166',
            circleRadius: 6,
            circleStrokeColor: '#111814',
            circleStrokeWidth: 2,
          ),
        ),
      );
    }
    if (widget.traveled.length >= 2) {
      _traveledLine = await controller.addLine(
        LineOptions(
          geometry: widget.traveled.map(_latLng).toList(growable: false),
          lineColor: '#64E6AE',
          lineWidth: 6,
          lineOpacity: 0.95,
          lineJoin: 'round',
        ),
      );
    }
  }

  Future<void> _fitRoute() async {
    final controller = _controller;
    final points = widget.traveled.length >= 2 ? widget.traveled : widget.route;
    if (controller == null || points.length < 2) return;
    var minimumLatitude = points.first.latitude;
    var maximumLatitude = points.first.latitude;
    var minimumLongitude = points.first.longitude;
    var maximumLongitude = points.first.longitude;
    for (final point in points.skip(1)) {
      minimumLatitude = point.latitude < minimumLatitude
          ? point.latitude
          : minimumLatitude;
      maximumLatitude = point.latitude > maximumLatitude
          ? point.latitude
          : maximumLatitude;
      minimumLongitude = point.longitude < minimumLongitude
          ? point.longitude
          : minimumLongitude;
      maximumLongitude = point.longitude > maximumLongitude
          ? point.longitude
          : maximumLongitude;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minimumLatitude, minimumLongitude),
          northeast: LatLng(maximumLatitude, maximumLongitude),
        ),
        left: 36,
        top: 36,
        right: 36,
        bottom: 36,
      ),
      duration: const Duration(milliseconds: 600),
    );
  }

  static LatLng _latLng(MapPoint point) =>
      LatLng(point.latitude, point.longitude);

  static double _bearing(MapPoint from, MapPoint to) {
    final fromLatitude = from.latitude * math.pi / 180;
    final toLatitude = to.latitude * math.pi / 180;
    final longitudeDelta = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(longitudeDelta) * math.cos(toLatitude);
    final x =
        math.cos(fromLatitude) * math.sin(toLatitude) -
        math.sin(fromLatitude) *
            math.cos(toLatitude) *
            math.cos(longitudeDelta);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
