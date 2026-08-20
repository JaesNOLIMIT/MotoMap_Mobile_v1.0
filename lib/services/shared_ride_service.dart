import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shared_ride.dart';

class SharedRideService {
  SharedRideService._();

  static final instance = SharedRideService._();
  SupabaseClient get _client => Supabase.instance.client;
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<SharedRide> create({
    required String routePlanId,
    String? motorcycleId,
  }) async {
    final id = await _client.rpc<String>(
      'create_shared_ride',
      params: {'p_route_plan_id': routePlanId, 'p_motorcycle_id': motorcycleId},
    );
    return fetch(id);
  }

  Future<SharedRide> join({required String code, String? motorcycleId}) async {
    final id = await _client.rpc<String>(
      'join_shared_ride',
      params: {
        'p_join_code': code.trim().toUpperCase(),
        'p_motorcycle_id': motorcycleId,
      },
    );
    return fetch(id);
  }

  Future<SharedRide?> fetchForRoute(String routePlanId) async {
    final row = await _client
        .from('shared_rides')
        .select('*, shared_ride_members(*)')
        .eq('route_plan_id', routePlanId)
        .maybeSingle();
    return row == null ? null : SharedRide.fromJson(row);
  }

  Future<SharedRide> fetch(String sharedRideId) async {
    final row = await _client
        .from('shared_rides')
        .select('*, shared_ride_members(*)')
        .eq('shared_ride_id', sharedRideId)
        .single();
    return SharedRide.fromJson(row);
  }

  Future<SharedRide> selectMotorcycle({
    required String sharedRideId,
    required String motorcycleId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in before choosing a motorcycle.');
    await _client
        .from('shared_ride_members')
        .update({
          'motorcycle_id': motorcycleId,
          'is_ready': false,
          'ready_at': null,
        })
        .eq('shared_ride_id', sharedRideId)
        .eq('user_id', user.id);
    return fetch(sharedRideId);
  }

  Future<SharedRide> setReady({
    required String sharedRideId,
    required bool isReady,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in before changing readiness.');
    await _client
        .from('shared_ride_members')
        .update({
          'is_ready': isReady,
          'ready_at': isReady ? DateTime.now().toUtc().toIso8601String() : null,
        })
        .eq('shared_ride_id', sharedRideId)
        .eq('user_id', user.id)
        .eq('status', 'joined');
    return fetch(sharedRideId);
  }

  Future<SharedRide> start(String sharedRideId) async {
    await _client.rpc<dynamic>(
      'start_shared_ride',
      params: {'p_shared_ride_id': sharedRideId},
    );
    return fetch(sharedRideId);
  }

  Future<void> sendAction({
    required String sharedRideId,
    required String action,
  }) async {
    const allowed = {'stopping', 'fuel', 'food', 'regroup', 'danger'};
    if (!allowed.contains(action)) {
      throw ArgumentError.value(action, 'action', 'Unsupported group action');
    }
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in before notifying the group.');
    await _client.from('shared_ride_events').insert({
      'shared_ride_id': sharedRideId,
      'user_id': user.id,
      'action': action,
    });
  }

  Future<List<SharedRideAction>> fetchActionsAfter({
    required String sharedRideId,
    required DateTime after,
  }) async {
    final rows = await _client
        .from('shared_ride_events')
        .select()
        .eq('shared_ride_id', sharedRideId)
        .gt('created_at', after.toUtc().toIso8601String())
        .order('created_at');
    return rows
        .map((row) => SharedRideAction.fromJson(row))
        .toList(growable: false);
  }
}
