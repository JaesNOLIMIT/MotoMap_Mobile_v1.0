class MapPoint {
  const MapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  List<double> toCoordinateJson() => [longitude, latitude];

  factory MapPoint.fromCoordinateJson(dynamic value) {
    final pair = value as List<dynamic>;
    return MapPoint((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
  }
}

class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.displayName,
    required this.location,
  });

  final String name;
  final String displayName;
  final MapPoint location;
}

enum RoutePreference { fastest, balanced, scenic, curvy }

extension RoutePreferenceValue on RoutePreference {
  String get databaseValue => name;

  String get label => switch (this) {
    RoutePreference.fastest => 'Fastest',
    RoutePreference.balanced => 'Balanced',
    RoutePreference.scenic => 'Scenic',
    RoutePreference.curvy => 'Curvy',
  };

  static RoutePreference fromDatabase(String? value) =>
      RoutePreference.values.firstWhere(
        (item) => item.name == value,
        orElse: () => RoutePreference.balanced,
      );
}

class RouteManeuver {
  const RouteManeuver({
    required this.instruction,
    required this.voiceInstruction,
    required this.beginShapeIndex,
    required this.endShapeIndex,
    required this.distanceKm,
    required this.durationSeconds,
    required this.type,
  });

  final String instruction;
  final String voiceInstruction;
  final int beginShapeIndex;
  final int endShapeIndex;
  final double distanceKm;
  final int durationSeconds;
  final int type;

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'voice_instruction': voiceInstruction,
    'begin_shape_index': beginShapeIndex,
    'end_shape_index': endShapeIndex,
    'distance_km': distanceKm,
    'duration_seconds': durationSeconds,
    'type': type,
  };

  factory RouteManeuver.fromJson(Map<String, dynamic> json) => RouteManeuver(
    instruction: json['instruction'] as String? ?? 'Continue',
    voiceInstruction:
        json['voice_instruction'] as String? ??
        json['instruction'] as String? ??
        'Continue',
    beginShapeIndex: (json['begin_shape_index'] as num?)?.toInt() ?? 0,
    endShapeIndex: (json['end_shape_index'] as num?)?.toInt() ?? 0,
    distanceKm: _asDouble(json['distance_km']) ?? 0,
    durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    type: (json['type'] as num?)?.toInt() ?? 0,
  );
}

class GeneratedRoute {
  const GeneratedRoute({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationSeconds,
    required this.coordinates,
    required this.maneuvers,
  });

  final MapPoint origin;
  final MapPoint destination;
  final double distanceKm;
  final int durationSeconds;
  final List<MapPoint> coordinates;
  final List<RouteManeuver> maneuvers;
}

class RoutePlan {
  const RoutePlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.source,
    required this.originName,
    required this.origin,
    required this.destinationName,
    required this.destination,
    required this.isLoop,
    required this.preference,
    required this.distanceKm,
    required this.durationSeconds,
    required this.coordinates,
    required this.maneuvers,
    required this.status,
    required this.createdAt,
    this.prompt,
    this.requestedDistanceKm,
    this.requestedDurationMinutes,
    this.scheduledFor,
  });

  final String id;
  final String userId;
  final String title;
  final String source;
  final String? prompt;
  final String originName;
  final MapPoint origin;
  final String destinationName;
  final MapPoint destination;
  final bool isLoop;
  final double? requestedDistanceKm;
  final int? requestedDurationMinutes;
  final RoutePreference preference;
  final double distanceKm;
  final int durationSeconds;
  final List<MapPoint> coordinates;
  final List<RouteManeuver> maneuvers;
  final DateTime? scheduledFor;
  final String status;
  final DateTime createdAt;

  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, dynamic> toDatabaseJson() => {
    'route_plan_id': id,
    'user_id': userId,
    'title': title,
    'source': source,
    'prompt': prompt,
    'origin_name': originName,
    'origin_latitude': origin.latitude,
    'origin_longitude': origin.longitude,
    'destination_name': destinationName,
    'destination_latitude': destination.latitude,
    'destination_longitude': destination.longitude,
    'is_loop': isLoop,
    'requested_distance_km': requestedDistanceKm,
    'requested_duration_minutes': requestedDurationMinutes,
    'route_preference': preference.databaseValue,
    'distance_km': distanceKm,
    'duration_seconds': durationSeconds,
    'route_coordinates': coordinates
        .map((point) => point.toCoordinateJson())
        .toList(growable: false),
    'maneuvers': maneuvers
        .map((maneuver) => maneuver.toJson())
        .toList(growable: false),
    'routing_provider': 'valhalla',
    'routing_profile': 'motorcycle',
    'provider_metadata': {
      'map_style': 'openfreemap_liberty',
      'geometry_precision': 6,
    },
    'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
    'status': status,
  };

  factory RoutePlan.fromJson(Map<String, dynamic> json) => RoutePlan(
    id: json['route_plan_id'] as String,
    userId: json['user_id'] as String,
    title: json['title'] as String,
    source: json['source'] as String? ?? 'manual',
    prompt: json['prompt'] as String?,
    originName: json['origin_name'] as String,
    origin: MapPoint(
      _asDouble(json['origin_latitude'])!,
      _asDouble(json['origin_longitude'])!,
    ),
    destinationName: json['destination_name'] as String,
    destination: MapPoint(
      _asDouble(json['destination_latitude'])!,
      _asDouble(json['destination_longitude'])!,
    ),
    isLoop: json['is_loop'] as bool? ?? false,
    requestedDistanceKm: _asDouble(json['requested_distance_km']),
    requestedDurationMinutes: (json['requested_duration_minutes'] as num?)
        ?.toInt(),
    preference: RoutePreferenceValue.fromDatabase(
      json['route_preference'] as String?,
    ),
    distanceKm: _asDouble(json['distance_km']) ?? 0,
    durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    coordinates: (json['route_coordinates'] as List<dynamic>? ?? const [])
        .map(MapPoint.fromCoordinateJson)
        .toList(growable: false),
    maneuvers: (json['maneuvers'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              RouteManeuver.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
    scheduledFor: json['scheduled_for'] == null
        ? null
        : DateTime.parse(json['scheduled_for'] as String),
    status: json['status'] as String? ?? 'planned',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

enum RideStatus { recording, paused, completed, discarded }

class RidePointSample {
  const RidePointSample({
    required this.sequenceNumber,
    required this.recordedAt,
    required this.location,
    required this.isPaused,
    this.altitudeM,
    this.accuracyM,
    this.bearingDegrees,
    this.gpsSpeedKph,
    this.engineRpm,
    this.ecuSpeedKph,
    this.coolantTemperatureC,
    this.fuelLevelPercent,
    this.fuelRateLph,
    this.controlModuleVoltage,
  });

  final int sequenceNumber;
  final DateTime recordedAt;
  final MapPoint location;
  final bool isPaused;
  final double? altitudeM;
  final double? accuracyM;
  final double? bearingDegrees;
  final double? gpsSpeedKph;
  final double? engineRpm;
  final double? ecuSpeedKph;
  final double? coolantTemperatureC;
  final double? fuelLevelPercent;
  final double? fuelRateLph;
  final double? controlModuleVoltage;

  Map<String, dynamic> toDatabaseJson({
    required String rideId,
    required String userId,
    required String motorcycleId,
  }) => {
    'ride_id': rideId,
    'user_id': userId,
    'motorcycle_id': motorcycleId,
    'sequence_number': sequenceNumber,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'latitude': location.latitude,
    'longitude': location.longitude,
    'altitude_m': altitudeM,
    'accuracy_m': accuracyM,
    'bearing_degrees': bearingDegrees,
    'gps_speed_kph': gpsSpeedKph,
    'is_paused': isPaused,
    'engine_rpm': engineRpm,
    'ecu_speed_kph': ecuSpeedKph,
    'coolant_temperature_c': coolantTemperatureC,
    'fuel_level_percent': fuelLevelPercent,
    'fuel_rate_lph': fuelRateLph,
    'control_module_voltage': controlModuleVoltage,
  };

  factory RidePointSample.fromJson(Map<String, dynamic> json) =>
      RidePointSample(
        sequenceNumber: (json['sequence_number'] as num).toInt(),
        recordedAt: DateTime.parse(json['recorded_at'] as String),
        location: MapPoint(
          _asDouble(json['latitude'])!,
          _asDouble(json['longitude'])!,
        ),
        isPaused: json['is_paused'] as bool? ?? false,
        altitudeM: _asDouble(json['altitude_m']),
        accuracyM: _asDouble(json['accuracy_m']),
        bearingDegrees: _asDouble(json['bearing_degrees']),
        gpsSpeedKph: _asDouble(json['gps_speed_kph']),
        engineRpm: _asDouble(json['engine_rpm']),
        ecuSpeedKph: _asDouble(json['ecu_speed_kph']),
        coolantTemperatureC: _asDouble(json['coolant_temperature_c']),
        fuelLevelPercent: _asDouble(json['fuel_level_percent']),
        fuelRateLph: _asDouble(json['fuel_rate_lph']),
        controlModuleVoltage: _asDouble(json['control_module_voltage']),
      );
}

class RideRecord {
  const RideRecord({
    required this.id,
    required this.userId,
    required this.motorcycleId,
    required this.title,
    required this.status,
    required this.startedAt,
    required this.pausedDurationSeconds,
    required this.reachedDestination,
    required this.distanceKm,
    required this.fuelIsEstimated,
    required this.scoreDetails,
    required this.routeCoordinates,
    this.routePlanId,
    this.diagnosticSessionId,
    this.endedAt,
    this.elapsedDurationSeconds,
    this.movingDurationSeconds,
    this.averageSpeedKph,
    this.maximumSpeedKph,
    this.fuelConsumedLiters,
    this.fuelCalculationMethod,
    this.completionPercent,
    this.ridingScore,
    this.motorcycleHealthScore,
  });

  final String id;
  final String userId;
  final String motorcycleId;
  final String? routePlanId;
  final String? diagnosticSessionId;
  final String title;
  final RideStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? elapsedDurationSeconds;
  final int? movingDurationSeconds;
  final int pausedDurationSeconds;
  final bool reachedDestination;
  final double distanceKm;
  final double? averageSpeedKph;
  final double? maximumSpeedKph;
  final double? fuelConsumedLiters;
  final bool fuelIsEstimated;
  final String? fuelCalculationMethod;
  final double? completionPercent;
  final int? ridingScore;
  final int? motorcycleHealthScore;
  final Map<String, dynamic> scoreDetails;
  final List<MapPoint> routeCoordinates;

  Duration get elapsedDuration => Duration(
    seconds:
        elapsedDurationSeconds ??
        (endedAt ?? DateTime.now()).difference(startedAt).inSeconds,
  );

  factory RideRecord.fromJson(Map<String, dynamic> json) => RideRecord(
    id: json['ride_id'] as String,
    userId: json['user_id'] as String,
    motorcycleId: json['motorcycle_id'] as String,
    routePlanId: json['route_plan_id'] as String?,
    diagnosticSessionId: json['diagnostic_session_id'] as String?,
    title: json['title'] as String,
    status: RideStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => RideStatus.completed,
    ),
    startedAt: DateTime.parse(json['started_at'] as String),
    endedAt: json['ended_at'] == null
        ? null
        : DateTime.parse(json['ended_at'] as String),
    elapsedDurationSeconds: (json['elapsed_duration_seconds'] as num?)?.toInt(),
    movingDurationSeconds: (json['moving_duration_seconds'] as num?)?.toInt(),
    pausedDurationSeconds:
        (json['paused_duration_seconds'] as num?)?.toInt() ?? 0,
    reachedDestination: json['reached_destination'] as bool? ?? false,
    distanceKm: _asDouble(json['distance_km']) ?? 0,
    averageSpeedKph: _asDouble(json['average_speed_kph']),
    maximumSpeedKph: _asDouble(json['maximum_speed_kph']),
    fuelConsumedLiters: _asDouble(json['fuel_consumed_liters']),
    fuelIsEstimated: json['fuel_is_estimated'] as bool? ?? false,
    fuelCalculationMethod: json['fuel_calculation_method'] as String?,
    completionPercent: _asDouble(json['completion_percent']),
    ridingScore: (json['riding_score'] as num?)?.toInt(),
    motorcycleHealthScore: (json['motorcycle_health_score'] as num?)?.toInt(),
    scoreDetails: Map<String, dynamic>.from(
      json['score_details'] as Map? ?? const {},
    ),
    routeCoordinates: (json['route_coordinates'] as List<dynamic>? ?? const [])
        .map(MapPoint.fromCoordinateJson)
        .toList(growable: false),
  );
}

double? _asDouble(dynamic value) => value is num
    ? value.toDouble()
    : value == null
    ? null
    : double.tryParse(value.toString());
