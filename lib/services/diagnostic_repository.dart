import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/diagnostic_data.dart';
import '../models/motorcycle.dart';

class DiagnosticRepository {
  DiagnosticRepository._();

  static final instance = DiagnosticRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No authenticated rider.');
    return user.id;
  }

  Future<String> startSession({
    required Motorcycle motorcycle,
    required DiagnosticSessionType type,
    String? elmVersion,
    String? protocol,
    double? adapterVoltage,
    List<String> supportedPids = const [],
  }) async {
    final row = await _client
        .from('diagnostic_sessions')
        .insert({
          'motorcycle_id': motorcycle.id,
          'user_id': _userId,
          'session_type': type.databaseValue,
          'elm_device_name': motorcycle.elmDeviceName,
          'elm_device_identifier': motorcycle.elmDeviceIdentifier,
          'elm_version': elmVersion,
          'detected_protocol': protocol,
          'adapter_voltage': adapterVoltage,
          'supported_pids': supportedPids,
        })
        .select('diagnostic_session_id')
        .single();
    return row['diagnostic_session_id'] as String;
  }

  Future<void> saveSnapshot({
    required String sessionId,
    required Motorcycle motorcycle,
    required DiagnosticSnapshot snapshot,
  }) async {
    if (!snapshot.hasAnyValue) return;
    await _client
        .from('diagnostic_samples')
        .insert(
          snapshot.toDatabaseJson(
            sessionId: sessionId,
            motorcycleId: motorcycle.id,
            userId: _userId,
          ),
        );
  }

  Future<void> saveTroubleCodes({
    required String sessionId,
    required Motorcycle motorcycle,
    required List<DiagnosticTroubleCode> codes,
  }) async {
    if (codes.isEmpty) return;
    await _client.from('diagnostic_trouble_codes').upsert([
      for (final code in codes)
        {
          'diagnostic_session_id': sessionId,
          'motorcycle_id': motorcycle.id,
          'user_id': _userId,
          'code': code.code,
          'status': code.status,
          'description': code.description,
          'raw_response': code.rawResponse,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
    ], onConflict: 'diagnostic_session_id,code,status');
  }

  Future<void> finishSession({
    required String sessionId,
    required int? healthScore,
    required List<String> issues,
    DiagnosticSessionSummary? summary,
  }) async {
    final values = <String, dynamic>{
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'health_score': healthScore,
      'score_details': {
        'issues': issues,
        'scoring_version': 'rules-v1',
        'ai_generated': false,
      },
    };
    if (summary != null) values.addAll(summary.toDatabaseJson());
    await _client
        .from('diagnostic_sessions')
        .update(values)
        .eq('diagnostic_session_id', sessionId)
        .eq('user_id', _userId);
  }

  Future<List<DiagnosticHistoryEntry>> fetchMotorcycleHistory(
    String motorcycleId, {
    int limit = 100,
  }) async {
    final rows = await _client
        .from('diagnostic_sessions')
        .select(
          'diagnostic_session_id, session_type, started_at, ended_at, '
          'health_score, score_details, detected_protocol, adapter_voltage, '
          'distance_km, fuel_consumed_liters, average_speed_kph, '
          'maximum_speed_kph, average_engine_rpm, maximum_engine_rpm, '
          'maximum_coolant_temperature_c, minimum_control_module_voltage, '
          'ending_fuel_level_percent, sample_count, trouble_code_count, '
          'trouble_codes',
        )
        .eq('motorcycle_id', motorcycleId)
        .eq('user_id', _userId)
        .order('started_at', ascending: false)
        .order('diagnostic_session_id', ascending: false)
        .limit(limit);
    return rows.map(DiagnosticHistoryEntry.fromJson).toList(growable: false);
  }

  Future<MotorcycleUsageSummary> fetchMotorcycleUsageSummary(
    String motorcycleId,
  ) async {
    final rows = await _client.rpc(
      'get_motorcycle_usage_summary',
      params: {'p_motorcycle_id': motorcycleId},
    );
    final resultRows = rows as List<dynamic>;
    final row = resultRows.isEmpty
        ? null
        : Map<String, dynamic>.from(resultRows.first as Map);
    if (row == null) {
      return const MotorcycleUsageSummary(
        recordedRideCount: 0,
        totalDistanceKm: null,
        totalFuelConsumedLiters: null,
      );
    }
    return MotorcycleUsageSummary(
      recordedRideCount: (row['recorded_ride_count'] as num?)?.toInt() ?? 0,
      totalDistanceKm: _asDouble(row['total_distance_km']),
      totalFuelConsumedLiters: _asDouble(row['total_fuel_consumed_liters']),
      estimatedFuelConsumedLiters: _asDouble(
        row['estimated_fuel_consumed_liters'],
      ),
      ridesWithEstimatedFuel:
          (row['rides_with_estimated_fuel'] as num?)?.toInt() ?? 0,
    );
  }

  static double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : value == null
      ? null
      : double.tryParse(value.toString());
}
