enum DiagnosticSessionType {
  preRide('pre_ride'),
  ride('ride'),
  postRide('post_ride'),
  manual('manual');

  const DiagnosticSessionType(this.databaseValue);
  final String databaseValue;
}

class DiagnosticSnapshot {
  const DiagnosticSnapshot({
    required this.recordedAt,
    this.engineRpm,
    this.vehicleSpeedKph,
    this.coolantTemperatureC,
    this.intakeAirTemperatureC,
    this.throttlePositionPercent,
    this.engineLoadPercent,
    this.fuelLevelPercent,
    this.controlModuleVoltage,
    this.distanceWithMilKm,
    this.runtimeSinceEngineStartSeconds,
    this.fuelRateLitersPerHour,
    this.extraPids = const {},
  });

  final DateTime recordedAt;
  final double? engineRpm;
  final double? vehicleSpeedKph;
  final double? coolantTemperatureC;
  final double? intakeAirTemperatureC;
  final double? throttlePositionPercent;
  final double? engineLoadPercent;
  final double? fuelLevelPercent;
  final double? controlModuleVoltage;
  final double? distanceWithMilKm;
  final int? runtimeSinceEngineStartSeconds;
  final double? fuelRateLitersPerHour;
  final Map<String, dynamic> extraPids;

  bool get hasAnyValue =>
      engineRpm != null ||
      vehicleSpeedKph != null ||
      coolantTemperatureC != null ||
      intakeAirTemperatureC != null ||
      throttlePositionPercent != null ||
      engineLoadPercent != null ||
      fuelLevelPercent != null ||
      controlModuleVoltage != null ||
      distanceWithMilKm != null ||
      runtimeSinceEngineStartSeconds != null ||
      fuelRateLitersPerHour != null ||
      extraPids.isNotEmpty;

  Map<String, dynamic> toDatabaseJson({
    required String sessionId,
    required String motorcycleId,
    required String userId,
  }) => {
    'diagnostic_session_id': sessionId,
    'motorcycle_id': motorcycleId,
    'user_id': userId,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'engine_rpm': engineRpm,
    'vehicle_speed_kph': vehicleSpeedKph,
    'coolant_temperature_c': coolantTemperatureC,
    'intake_air_temperature_c': intakeAirTemperatureC,
    'throttle_position_percent': throttlePositionPercent,
    'engine_load_percent': engineLoadPercent,
    'fuel_level_percent': fuelLevelPercent,
    'control_module_voltage': controlModuleVoltage,
    'distance_with_mil_km': distanceWithMilKm,
    'runtime_since_engine_start_seconds': runtimeSinceEngineStartSeconds,
    'fuel_rate_lph': fuelRateLitersPerHour,
    'extra_pids': extraPids,
  };
}

class DiagnosticTroubleCode {
  const DiagnosticTroubleCode({
    required this.code,
    required this.status,
    this.description,
    this.rawResponse,
  });

  final String code;
  final String status;
  final String? description;
  final String? rawResponse;
}

class DiagnosticReport {
  const DiagnosticReport({
    required this.sessionId,
    required this.snapshot,
    required this.troubleCodes,
    required this.healthScore,
    required this.issues,
    required this.elmVersion,
    required this.protocol,
    required this.adapterVoltage,
  });

  final String sessionId;
  final DiagnosticSnapshot snapshot;
  final List<DiagnosticTroubleCode> troubleCodes;
  final int healthScore;
  final List<String> issues;
  final String? elmVersion;
  final String? protocol;
  final double? adapterVoltage;
}

class DiagnosticSessionSummary {
  const DiagnosticSessionSummary({
    required this.sampleCount,
    required this.troubleCodes,
    this.distanceKm,
    this.fuelConsumedLiters,
    this.averageSpeedKph,
    this.maximumSpeedKph,
    this.averageEngineRpm,
    this.maximumEngineRpm,
    this.maximumCoolantTemperatureC,
    this.minimumControlModuleVoltage,
    this.endingFuelLevelPercent,
  });

  final double? distanceKm;
  final double? fuelConsumedLiters;
  final double? averageSpeedKph;
  final double? maximumSpeedKph;
  final double? averageEngineRpm;
  final double? maximumEngineRpm;
  final double? maximumCoolantTemperatureC;
  final double? minimumControlModuleVoltage;
  final double? endingFuelLevelPercent;
  final int sampleCount;
  final List<DiagnosticTroubleCode> troubleCodes;

  Map<String, dynamic> toDatabaseJson() => {
    'distance_km': distanceKm,
    'fuel_consumed_liters': fuelConsumedLiters,
    'average_speed_kph': averageSpeedKph,
    'maximum_speed_kph': maximumSpeedKph,
    'average_engine_rpm': averageEngineRpm,
    'maximum_engine_rpm': maximumEngineRpm,
    'maximum_coolant_temperature_c': maximumCoolantTemperatureC,
    'minimum_control_module_voltage': minimumControlModuleVoltage,
    'ending_fuel_level_percent': endingFuelLevelPercent,
    'sample_count': sampleCount,
    'trouble_code_count': troubleCodes.length,
    'trouble_codes': troubleCodes.map((code) => code.code).toList(),
  };

  factory DiagnosticSessionSummary.fromSnapshot(
    DiagnosticSnapshot snapshot,
    List<DiagnosticTroubleCode> troubleCodes,
  ) => DiagnosticSessionSummary(
    sampleCount: snapshot.hasAnyValue ? 1 : 0,
    troubleCodes: troubleCodes,
    averageSpeedKph: snapshot.vehicleSpeedKph,
    maximumSpeedKph: snapshot.vehicleSpeedKph,
    averageEngineRpm: snapshot.engineRpm,
    maximumEngineRpm: snapshot.engineRpm,
    maximumCoolantTemperatureC: snapshot.coolantTemperatureC,
    minimumControlModuleVoltage: snapshot.controlModuleVoltage,
    endingFuelLevelPercent: snapshot.fuelLevelPercent,
  );
}

class DiagnosticHistoryEntry {
  const DiagnosticHistoryEntry({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.scoreDetails,
    required this.sampleCount,
    required this.troubleCodeCount,
    required this.troubleCodes,
    this.endedAt,
    this.healthScore,
    this.protocol,
    this.adapterVoltage,
    this.distanceKm,
    this.fuelConsumedLiters,
    this.averageSpeedKph,
    this.maximumSpeedKph,
    this.averageEngineRpm,
    this.maximumEngineRpm,
    this.maximumCoolantTemperatureC,
    this.minimumControlModuleVoltage,
    this.endingFuelLevelPercent,
  });

  final String id;
  final String type;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? healthScore;
  final Map<String, dynamic> scoreDetails;
  final String? protocol;
  final double? adapterVoltage;
  final double? distanceKm;
  final double? fuelConsumedLiters;
  final double? averageSpeedKph;
  final double? maximumSpeedKph;
  final double? averageEngineRpm;
  final double? maximumEngineRpm;
  final double? maximumCoolantTemperatureC;
  final double? minimumControlModuleVoltage;
  final double? endingFuelLevelPercent;
  final int sampleCount;
  final int troubleCodeCount;
  final List<String> troubleCodes;

  bool get isRide => type == DiagnosticSessionType.ride.databaseValue;

  Duration? get duration => endedAt?.difference(startedAt);

  String get typeLabel => switch (type) {
    'pre_ride' => 'Pre-ride check',
    'post_ride' => 'Post-ride check',
    'ride' => 'Recorded ride',
    _ => 'Manual diagnostic',
  };

  List<String> get issues =>
      (scoreDetails['issues'] as List<dynamic>? ?? const [])
          .map((issue) => issue.toString())
          .toList(growable: false);

  factory DiagnosticHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DiagnosticHistoryEntry(
        id: json['diagnostic_session_id'] as String,
        type: json['session_type'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.parse(json['ended_at'] as String),
        healthScore: json['health_score'] as int?,
        scoreDetails: Map<String, dynamic>.from(
          json['score_details'] as Map? ?? const {},
        ),
        protocol: json['detected_protocol'] as String?,
        adapterVoltage: _asDouble(json['adapter_voltage']),
        distanceKm: _asDouble(json['distance_km']),
        fuelConsumedLiters: _asDouble(json['fuel_consumed_liters']),
        averageSpeedKph: _asDouble(json['average_speed_kph']),
        maximumSpeedKph: _asDouble(json['maximum_speed_kph']),
        averageEngineRpm: _asDouble(json['average_engine_rpm']),
        maximumEngineRpm: _asDouble(json['maximum_engine_rpm']),
        maximumCoolantTemperatureC: _asDouble(
          json['maximum_coolant_temperature_c'],
        ),
        minimumControlModuleVoltage: _asDouble(
          json['minimum_control_module_voltage'],
        ),
        endingFuelLevelPercent: _asDouble(json['ending_fuel_level_percent']),
        sampleCount: json['sample_count'] as int? ?? 0,
        troubleCodeCount: json['trouble_code_count'] as int? ?? 0,
        troubleCodes: (json['trouble_codes'] as List<dynamic>? ?? const [])
            .map((code) => code.toString())
            .toList(growable: false),
      );

  static double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : value == null
      ? null
      : double.tryParse(value.toString());
}

class MotorcycleUsageSummary {
  const MotorcycleUsageSummary({
    required this.recordedRideCount,
    required this.totalDistanceKm,
    required this.totalFuelConsumedLiters,
  });

  final int recordedRideCount;
  final double? totalDistanceKm;
  final double? totalFuelConsumedLiters;

  factory MotorcycleUsageSummary.fromHistory(
    List<DiagnosticHistoryEntry> history,
  ) {
    final rides = history.where((entry) => entry.isRide).toList();
    final distances = rides
        .map((entry) => entry.distanceKm)
        .whereType<double>()
        .toList();
    final fuelValues = rides
        .map((entry) => entry.fuelConsumedLiters)
        .whereType<double>()
        .toList();
    return MotorcycleUsageSummary(
      recordedRideCount: rides.length,
      totalDistanceKm: distances.isEmpty
          ? null
          : distances.fold<double>(0, (total, value) => total + value),
      totalFuelConsumedLiters: fuelValues.isEmpty
          ? null
          : fuelValues.fold<double>(0, (total, value) => total + value),
    );
  }
}
