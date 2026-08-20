import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/motorcycle.dart';
import '../models/ride_data.dart';

class RideRepository {
  RideRepository._();

  static final instance = RideRepository._();
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static const _uuid = Uuid();
  static const _pendingStartsKey = 'motomap.pending_ride_starts.v1';
  static const _pendingPointsKey = 'motomap.pending_ride_points.v1';
  static const _pendingFinishesKey = 'motomap.pending_ride_finishes.v1';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in before planning or recording.');
    return user.id;
  }

  Future<RoutePlan> saveRoutePlan({
    required GeneratedRoute route,
    required String title,
    required String source,
    required String originName,
    required String destinationName,
    required bool isLoop,
    required RoutePreference preference,
    String? prompt,
    double? requestedDistanceKm,
    int? requestedDurationMinutes,
    DateTime? scheduledFor,
    String? motorcycleId,
    List<RouteWaypoint> waypoints = const [],
    String departureMode = 'now',
    bool avoidHighways = false,
    bool avoidTolls = false,
  }) async {
    final plan = RoutePlan(
      id: _uuid.v4(),
      userId: _userId,
      title: title.trim(),
      source: source,
      prompt: _nullIfEmpty(prompt),
      originName: originName,
      origin: route.origin,
      destinationName: destinationName,
      destination: route.destination,
      isLoop: isLoop,
      requestedDistanceKm: requestedDistanceKm,
      requestedDurationMinutes: requestedDurationMinutes,
      preference: preference,
      distanceKm: route.distanceKm,
      durationSeconds: route.durationSeconds,
      coordinates: route.coordinates,
      maneuvers: route.maneuvers,
      scheduledFor: scheduledFor,
      motorcycleId: motorcycleId,
      waypoints: waypoints,
      departureMode: departureMode,
      avoidHighways: avoidHighways,
      avoidTolls: avoidTolls,
      status: 'planned',
      createdAt: DateTime.now().toUtc(),
    );
    final row = await _client
        .from('route_plans')
        .insert(plan.toDatabaseJson())
        .select()
        .single();
    changes.value++;
    return RoutePlan.fromJson(row);
  }

  Future<RoutePlan> updateRoutePlan(
    RoutePlan plan, {
    required GeneratedRoute route,
    required RoutePreference preference,
    required List<RouteWaypoint> waypoints,
    required bool avoidHighways,
    required bool avoidTolls,
    String? motorcycleId,
    String? originName,
    String? destinationName,
  }) async {
    final row = await _client
        .from('route_plans')
        .update({
          'origin_latitude': route.origin.latitude,
          'origin_longitude': route.origin.longitude,
          if (originName != null) 'origin_name': originName,
          'destination_latitude': route.destination.latitude,
          'destination_longitude': route.destination.longitude,
          if (destinationName != null) 'destination_name': destinationName,
          'route_preference': preference.databaseValue,
          'distance_km': route.distanceKm,
          'duration_seconds': route.durationSeconds,
          'route_coordinates': route.coordinates
              .map((point) => point.toCoordinateJson())
              .toList(growable: false),
          'maneuvers': route.maneuvers
              .map((maneuver) => maneuver.toJson())
              .toList(growable: false),
          'waypoints': waypoints
              .map((waypoint) => waypoint.toJson())
              .toList(growable: false),
          'avoid_highways': avoidHighways,
          'avoid_tolls': avoidTolls,
          'motorcycle_id': motorcycleId,
        })
        .eq('route_plan_id', plan.id)
        .eq('user_id', _userId)
        .select()
        .single();
    changes.value++;
    return RoutePlan.fromJson(row);
  }

  Future<List<RoutePlan>> fetchPlannedRoutes({int limit = 100}) async {
    final rows = await _client
        .from('route_plans')
        .select()
        .eq('user_id', _userId)
        .eq('status', 'planned')
        .order('scheduled_for', ascending: true, nullsFirst: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(RoutePlan.fromJson).toList(growable: false);
  }

  Future<RoutePlan> fetchRoutePlan(String routePlanId) async {
    final row = await _client
        .from('route_plans')
        .select()
        .eq('route_plan_id', routePlanId)
        .single();
    return RoutePlan.fromJson(row);
  }

  Future<List<RoutePlan>> fetchArchivedRoutes({int limit = 100}) async {
    final rows = await _client
        .from('route_plans')
        .select()
        .eq('user_id', _userId)
        .eq('status', 'archived')
        .order('updated_at', ascending: false)
        .limit(limit);
    return rows.map(RoutePlan.fromJson).toList(growable: false);
  }

  Future<void> archiveRoute(String routePlanId, {bool notify = true}) async {
    await _client
        .from('route_plans')
        .update({'status': 'archived'})
        .eq('route_plan_id', routePlanId)
        .eq('user_id', _userId);
    if (notify) changes.value++;
  }

  Future<void> deleteRoute(String routePlanId, {bool notify = true}) async {
    await _client
        .from('route_plans')
        .delete()
        .eq('route_plan_id', routePlanId)
        .eq('user_id', _userId);
    if (notify) changes.value++;
  }

  Future<void> restoreRoute(String routePlanId, {bool notify = true}) async {
    await _client
        .from('route_plans')
        .update({'status': 'planned'})
        .eq('route_plan_id', routePlanId)
        .eq('user_id', _userId);
    if (notify) changes.value++;
  }

  Future<RideRecord> startRide({
    required Motorcycle motorcycle,
    required String title,
    RoutePlan? plan,
    String? diagnosticSessionId,
    MapPoint? start,
  }) async {
    final id = _uuid.v4();
    final startedAt = DateTime.now().toUtc();
    final values = <String, dynamic>{
      'ride_id': id,
      'user_id': _userId,
      'motorcycle_id': motorcycle.id,
      'route_plan_id': plan?.id,
      'diagnostic_session_id': diagnosticSessionId,
      'title': title.trim(),
      'status': 'recording',
      'started_at': startedAt.toIso8601String(),
      'start_latitude': start?.latitude,
      'start_longitude': start?.longitude,
      'destination_latitude': plan?.destination.latitude,
      'destination_longitude': plan?.destination.longitude,
      'route_coordinates':
          plan?.coordinates
              .map((point) => point.toCoordinateJson())
              .toList(growable: false) ??
          const [],
    };
    Map<String, dynamic> row;
    try {
      row = await _client.from('rides').insert(values).select().single();
    } catch (_) {
      await _appendPendingMap(_pendingStartsKey, values);
      row = {
        ...values,
        'paused_duration_seconds': 0,
        'reached_destination': false,
        'distance_km': 0,
        'fuel_is_estimated': false,
        'score_details': <String, dynamic>{},
      };
    }
    return RideRecord.fromJson(row);
  }

  Future<void> setRideStatus(String rideId, RideStatus status) async {
    try {
      await _client
          .from('rides')
          .update({'status': status.name})
          .eq('ride_id', rideId)
          .eq('user_id', _userId);
    } catch (_) {
      // The final ride update contains the authoritative status and durations.
    }
  }

  Future<String?> startPause({
    required String rideId,
    required Motorcycle motorcycle,
    required DateTime pausedAt,
  }) async {
    try {
      final row = await _client
          .from('ride_pauses')
          .insert({
            'ride_id': rideId,
            'user_id': _userId,
            'motorcycle_id': motorcycle.id,
            'paused_at': pausedAt.toUtc().toIso8601String(),
            'reason': 'manual',
          })
          .select('ride_pause_id')
          .single();
      return row['ride_pause_id'].toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> resumePause(String? pauseId, DateTime resumedAt) async {
    if (pauseId == null) return;
    try {
      await _client
          .from('ride_pauses')
          .update({'resumed_at': resumedAt.toUtc().toIso8601String()})
          .eq('ride_pause_id', pauseId)
          .eq('user_id', _userId);
    } catch (_) {
      // Total pause time remains preserved on the parent ride.
    }
  }

  Future<void> savePoints({
    required String rideId,
    required Motorcycle motorcycle,
    required List<RidePointSample> points,
  }) async {
    if (points.isEmpty) return;
    final rows = [
      for (final point in points)
        point.toDatabaseJson(
          rideId: rideId,
          userId: _userId,
          motorcycleId: motorcycle.id,
        ),
    ];
    try {
      await _client
          .from('ride_points')
          .upsert(rows, onConflict: 'ride_id,sequence_number');
    } catch (_) {
      for (final row in rows) {
        await _appendPendingMap(_pendingPointsKey, row);
      }
    }
  }

  Future<void> finishRide({
    required String rideId,
    required DateTime endedAt,
    required int elapsedSeconds,
    required int movingSeconds,
    required int pausedSeconds,
    required MapPoint? end,
    required bool reachedDestination,
    required double distanceKm,
    required double? averageSpeedKph,
    required double? maximumSpeedKph,
    required double? fuelConsumedLiters,
    required bool fuelIsEstimated,
    required double completionPercent,
    required int ridingScore,
    required int? motorcycleHealthScore,
    required Map<String, dynamic> scoreDetails,
    required List<MapPoint> routeCoordinates,
    String? routePlanId,
  }) async {
    final values = <String, dynamic>{
      'ride_id': rideId,
      'user_id': _userId,
      'status': 'completed',
      'ended_at': endedAt.toUtc().toIso8601String(),
      'elapsed_duration_seconds': elapsedSeconds,
      'moving_duration_seconds': movingSeconds,
      'paused_duration_seconds': pausedSeconds,
      'end_latitude': end?.latitude,
      'end_longitude': end?.longitude,
      'reached_destination': reachedDestination,
      'distance_km': distanceKm,
      'average_speed_kph': averageSpeedKph,
      'maximum_speed_kph': maximumSpeedKph,
      'fuel_consumed_liters': fuelConsumedLiters,
      'fuel_is_estimated': fuelIsEstimated,
      'fuel_calculation_method': fuelConsumedLiters == null
          ? null
          : fuelIsEstimated
          ? 'distance_estimate'
          : 'obd_pid_5e',
      'completion_percent': completionPercent,
      'riding_score': ridingScore,
      'motorcycle_health_score': motorcycleHealthScore,
      'score_details': scoreDetails,
      'route_coordinates': routeCoordinates
          .map((point) => point.toCoordinateJson())
          .toList(growable: false),
      if (routePlanId != null) '_route_plan_id': routePlanId,
    };
    try {
      await syncPending();
      await _applyFinish(values);
      if (routePlanId != null) {
        await _client
            .from('route_plans')
            .update({'status': 'completed'})
            .eq('route_plan_id', routePlanId)
            .eq('user_id', _userId);
      }
      changes.value++;
    } catch (_) {
      await _appendPendingMap(_pendingFinishesKey, values);
    }
  }

  Future<List<RideRecord>> fetchCompletedRides({int limit = 100}) async {
    final rows = await _client
        .from('rides')
        .select()
        .eq('user_id', _userId)
        .eq('status', 'completed')
        .order('started_at', ascending: false)
        .limit(limit);
    return rows.map(RideRecord.fromJson).toList(growable: false);
  }

  Future<List<RidePointSample>> fetchRidePoints(String rideId) async {
    final rows = await _client
        .from('ride_points')
        .select()
        .eq('ride_id', rideId)
        .eq('user_id', _userId)
        .order('sequence_number');
    return rows.map(RidePointSample.fromJson).toList(growable: false);
  }

  Future<void> syncPending() async {
    if (_client.auth.currentUser == null) return;
    final preferences = await SharedPreferences.getInstance();

    final starts = _decodePending(preferences.getString(_pendingStartsKey));
    if (starts.isNotEmpty) {
      await _client.from('rides').upsert(starts, onConflict: 'ride_id');
      await preferences.remove(_pendingStartsKey);
    }

    final points = _decodePending(preferences.getString(_pendingPointsKey));
    if (points.isNotEmpty) {
      for (var index = 0; index < points.length; index += 100) {
        final end = (index + 100).clamp(0, points.length);
        await _client
            .from('ride_points')
            .upsert(
              points.sublist(index, end),
              onConflict: 'ride_id,sequence_number',
            );
      }
      await preferences.remove(_pendingPointsKey);
    }

    final finishes = _decodePending(preferences.getString(_pendingFinishesKey));
    for (final finish in finishes) {
      await _applyFinish(finish);
      final routePlanId = finish['_route_plan_id'] as String?;
      if (routePlanId != null) {
        await _client
            .from('route_plans')
            .update({'status': 'completed'})
            .eq('route_plan_id', routePlanId)
            .eq('user_id', _userId);
      }
    }
    if (finishes.isNotEmpty) await preferences.remove(_pendingFinishesKey);
    if (starts.isNotEmpty || points.isNotEmpty || finishes.isNotEmpty) {
      changes.value++;
    }
  }

  void notifyRefresh() => changes.value++;

  Future<void> _applyFinish(Map<String, dynamic> values) async {
    final rideId = values['ride_id'] as String;
    final userId = values['user_id'] as String;
    final update = Map<String, dynamic>.from(values)
      ..remove('ride_id')
      ..remove('user_id')
      ..remove('_route_plan_id');
    await _client
        .from('rides')
        .update(update)
        .eq('ride_id', rideId)
        .eq('user_id', userId);
  }

  Future<void> _appendPendingMap(String key, Map<String, dynamic> value) async {
    final preferences = await SharedPreferences.getInstance();
    final items = _decodePending(preferences.getString(key));
    if (key == _pendingPointsKey) {
      final rideId = value['ride_id'];
      final sequence = value['sequence_number'];
      items.removeWhere(
        (item) =>
            item['ride_id'] == rideId && item['sequence_number'] == sequence,
      );
    } else {
      final rideId = value['ride_id'];
      items.removeWhere((item) => item['ride_id'] == rideId);
    }
    items.add(value);
    await preferences.setString(key, jsonEncode(items));
  }

  static List<Map<String, dynamic>> _decodePending(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String? _nullIfEmpty(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
