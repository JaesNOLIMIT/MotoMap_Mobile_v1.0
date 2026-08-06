import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/map_config.dart';
import '../models/ride_data.dart';

class SmartPlanIntent {
  const SmartPlanIntent({
    required this.isLoop,
    required this.preference,
    this.destinationQuery,
    this.distanceKm,
    this.durationMinutes,
  });

  final bool isLoop;
  final String? destinationQuery;
  final double? distanceKm;
  final int? durationMinutes;
  final RoutePreference preference;
}

class RoutingService {
  RoutingService._();

  static final instance = RoutingService._();
  final http.Client _client = http.Client();

  Future<List<PlaceResult>> searchPlaces(String query, {MapPoint? near}) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];
    final parameters = <String, String>{
      'q': clean,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'accept-language': 'en',
    };
    if (near != null) {
      const span = 2.5;
      parameters['viewbox'] =
          '${near.longitude - span},${near.latitude + span},'
          '${near.longitude + span},${near.latitude - span}';
    }
    final uri = Uri.parse(
      '${MapConfig.geocoderUrl}/search',
    ).replace(queryParameters: parameters);
    final response = await _client.get(
      uri,
      headers: {
        if (!kIsWeb) 'User-Agent': MapConfig.userAgent,
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('Destination search is temporarily unavailable.');
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((item) {
          final row = Map<String, dynamic>.from(item as Map);
          final display = row['display_name'] as String? ?? clean;
          final address = Map<String, dynamic>.from(
            row['address'] as Map? ?? {},
          );
          final name =
              row['name'] as String? ??
              address['road'] as String? ??
              address['city'] as String? ??
              display.split(',').first;
          return PlaceResult(
            name: name,
            displayName: display,
            location: MapPoint(
              double.parse(row['lat'].toString()),
              double.parse(row['lon'].toString()),
            ),
          );
        })
        .toList(growable: false);
  }

  Future<GeneratedRoute> routeToDestination({
    required MapPoint origin,
    required MapPoint destination,
    required RoutePreference preference,
  }) => _requestRoute(locations: [origin, destination], preference: preference);

  Future<GeneratedRoute> createLoop({
    required MapPoint origin,
    required double requestedDistanceKm,
    required RoutePreference preference,
  }) async {
    final distance = requestedDistanceKm.clamp(3, 5000).toDouble();
    final legRadiusKm = distance / (2 + math.sqrt(2));
    final angle = switch (preference) {
      RoutePreference.fastest => 20.0,
      RoutePreference.balanced => 45.0,
      RoutePreference.scenic => 80.0,
      RoutePreference.curvy => 120.0,
    };
    final first = _destinationPoint(origin, legRadiusKm, angle);
    final second = _destinationPoint(origin, legRadiusKm, angle + 90);
    return _requestRoute(
      locations: [origin, first, second, origin],
      preference: preference,
    );
  }

  Future<GeneratedRoute> reroute({
    required MapPoint current,
    required MapPoint destination,
    required RoutePreference preference,
  }) => routeToDestination(
    origin: current,
    destination: destination,
    preference: preference,
  );

  SmartPlanIntent parsePrompt(String prompt) {
    final clean = prompt.trim();
    final lower = clean.toLowerCase();
    final distanceMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:km|kilometers?|kilometres?)\b',
    ).firstMatch(lower);
    final hourMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b',
    ).firstMatch(lower);
    final minuteMatch = RegExp(
      r'(\d+)\s*(?:minutes?|mins?)\b',
    ).firstMatch(lower);
    final isLoop = lower.contains('loop') || lower.contains('round trip');
    final preference = lower.contains('curvy') || lower.contains('twisty')
        ? RoutePreference.curvy
        : lower.contains('scenic') ||
              lower.contains('view') ||
              lower.contains('mountain')
        ? RoutePreference.scenic
        : lower.contains('fast') || lower.contains('quick')
        ? RoutePreference.fastest
        : RoutePreference.balanced;

    String? destination;
    if (!isLoop) {
      final match = RegExp(
        r'\bto\s+(.+?)(?:\s+(?:for|with|using|avoiding)\b|[,.]|$)',
        caseSensitive: false,
      ).firstMatch(clean);
      destination = match?.group(1)?.trim();
      if (destination?.isEmpty == true) destination = null;
    }

    final hours = double.tryParse(hourMatch?.group(1) ?? '');
    final minutes = int.tryParse(minuteMatch?.group(1) ?? '');
    return SmartPlanIntent(
      isLoop: isLoop,
      destinationQuery: destination,
      distanceKm: double.tryParse(distanceMatch?.group(1) ?? ''),
      durationMinutes:
          (hours == null ? 0 : (hours * 60).round()) + (minutes ?? 0) == 0
          ? null
          : (hours == null ? 0 : (hours * 60).round()) + (minutes ?? 0),
      preference: preference,
    );
  }

  Future<GeneratedRoute> _requestRoute({
    required List<MapPoint> locations,
    required RoutePreference preference,
  }) async {
    final body = {
      'locations': [
        for (final point in locations)
          {'lat': point.latitude, 'lon': point.longitude, 'type': 'break'},
      ],
      'costing': 'motorcycle',
      'costing_options': {'motorcycle': _costingOptions(preference)},
      'units': 'kilometers',
      'language': 'en-US',
      'directions_options': {'units': 'kilometers'},
    };
    final response = await _client.get(
      Uri.parse(
        '${MapConfig.routerUrl}/route',
      ).replace(queryParameters: {'json': jsonEncode(body)}),
      headers: {
        if (!kIsWeb) 'User-Agent': MapConfig.userAgent,
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _routingError(response.body);
      throw StateError(message);
    }
    final root = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final trip = Map<String, dynamic>.from(root['trip'] as Map? ?? {});
    final summary = Map<String, dynamic>.from(trip['summary'] as Map? ?? {});
    final coordinates = <MapPoint>[];
    final maneuvers = <RouteManeuver>[];
    for (final rawLeg in trip['legs'] as List<dynamic>? ?? const []) {
      final leg = Map<String, dynamic>.from(rawLeg as Map);
      final legCoordinates = decodePolyline(leg['shape'] as String? ?? '');
      final baseIndex = coordinates.isEmpty ? 0 : coordinates.length - 1;
      if (coordinates.isEmpty) {
        coordinates.addAll(legCoordinates);
      } else if (legCoordinates.isNotEmpty) {
        coordinates.addAll(legCoordinates.skip(1));
      }
      for (final rawManeuver
          in leg['maneuvers'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawManeuver as Map);
        final instruction = item['instruction'] as String? ?? 'Continue';
        maneuvers.add(
          RouteManeuver(
            instruction: instruction,
            voiceInstruction:
                item['verbal_pre_transition_instruction'] as String? ??
                item['verbal_transition_alert_instruction'] as String? ??
                instruction,
            beginShapeIndex:
                baseIndex + ((item['begin_shape_index'] as num?)?.toInt() ?? 0),
            endShapeIndex:
                baseIndex + ((item['end_shape_index'] as num?)?.toInt() ?? 0),
            distanceKm: _asDouble(item['length']) ?? 0,
            durationSeconds: (item['time'] as num?)?.toInt() ?? 0,
            type: (item['type'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    if (coordinates.length < 2) {
      throw StateError('The routing service did not return a usable road.');
    }
    return GeneratedRoute(
      origin: coordinates.first,
      destination: coordinates.last,
      distanceKm: _asDouble(summary['length']) ?? 0,
      durationSeconds: (summary['time'] as num?)?.toInt() ?? 0,
      coordinates: coordinates,
      maneuvers: maneuvers,
    );
  }

  static Map<String, double> _costingOptions(RoutePreference preference) =>
      switch (preference) {
        RoutePreference.fastest => {
          'use_highways': 0.9,
          'use_tolls': 0.7,
          'use_trails': 0.0,
        },
        RoutePreference.balanced => {
          'use_highways': 0.55,
          'use_tolls': 0.35,
          'use_trails': 0.05,
        },
        RoutePreference.scenic => {
          'use_highways': 0.2,
          'use_tolls': 0.1,
          'use_trails': 0.1,
        },
        RoutePreference.curvy => {
          'use_highways': 0.05,
          'use_tolls': 0.05,
          'use_trails': 0.15,
        },
      };

  static String _routingError(String body) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(body) as Map);
      return json['error'] as String? ??
          json['error_message'] as String? ??
          'No motorcycle route could be generated for those locations.';
    } catch (_) {
      return 'Motorcycle routing is temporarily unavailable.';
    }
  }

  static List<MapPoint> decodePolyline(String encoded, {int precision = 6}) {
    if (encoded.isEmpty) return const [];
    final factor = math.pow(10, precision).toDouble();
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    final result = <MapPoint>[];
    while (index < encoded.length) {
      var shift = 0;
      var value = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        value |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      latitude += (value & 1) != 0 ? ~(value >> 1) : value >> 1;
      shift = 0;
      value = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        value |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      longitude += (value & 1) != 0 ? ~(value >> 1) : value >> 1;
      result.add(MapPoint(latitude / factor, longitude / factor));
    }
    return result;
  }

  static MapPoint _destinationPoint(
    MapPoint origin,
    double distanceKm,
    double bearingDegrees,
  ) {
    const earthRadiusKm = 6371.0088;
    final angularDistance = distanceKm / earthRadiusKm;
    final bearing = bearingDegrees * math.pi / 180;
    final latitude1 = origin.latitude * math.pi / 180;
    final longitude1 = origin.longitude * math.pi / 180;
    final latitude2 = math.asin(
      math.sin(latitude1) * math.cos(angularDistance) +
          math.cos(latitude1) * math.sin(angularDistance) * math.cos(bearing),
    );
    final longitude2 =
        longitude1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(latitude1),
          math.cos(angularDistance) - math.sin(latitude1) * math.sin(latitude2),
        );
    return MapPoint(latitude2 * 180 / math.pi, longitude2 * 180 / math.pi);
  }

  static double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : value == null
      ? null
      : double.tryParse(value.toString());
}
