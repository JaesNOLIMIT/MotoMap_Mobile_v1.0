import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/motorcycle.dart';

class MotorcycleService {
  MotorcycleService._();

  static final instance = MotorcycleService._();
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No authenticated rider.');
    return user.id;
  }

  Future<List<Motorcycle>> fetchMotorcycles() async {
    final rows = await _client
        .from('motorcycles')
        .select()
        .eq('user_id', _userId)
        .order('is_primary', ascending: false)
        .order('created_at');
    return rows.map(Motorcycle.fromJson).toList(growable: false);
  }

  Future<Motorcycle?> fetchPrimaryMotorcycle() async {
    final row = await _client
        .from('motorcycles')
        .select()
        .eq('user_id', _userId)
        .eq('is_primary', true)
        .maybeSingle();
    return row == null ? null : Motorcycle.fromJson(row);
  }

  Future<Motorcycle?> fetchLastConnectedMotorcycle() async {
    final row = await _client
        .from('motorcycles')
        .select()
        .eq('user_id', _userId)
        .not('last_elm_connected_at', 'is', null)
        .not('elm_device_identifier', 'is', null)
        .order('last_elm_connected_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : Motorcycle.fromJson(row);
  }

  Future<Motorcycle?> fetchReconnectMotorcycle() async {
    final lastConnected = await fetchLastConnectedMotorcycle();
    return lastConnected ?? await fetchPrimaryMotorcycle();
  }

  Future<Motorcycle> fetchMotorcycle(String motorcycleId) async {
    final row = await _client
        .from('motorcycles')
        .select()
        .eq('motorcycle_id', motorcycleId)
        .eq('user_id', _userId)
        .single();
    return Motorcycle.fromJson(row);
  }

  Future<Motorcycle> createMotorcycle(NewMotorcycle input) async {
    final existing = await fetchMotorcycles();
    var row = await _client
        .from('motorcycles')
        .insert({
          'user_id': _userId,
          'nickname': _nullIfEmpty(input.nickname),
          'make': input.make.trim(),
          'model': input.model.trim(),
          'model_year': input.modelYear,
          'motorcycle_type': input.type,
          'engine_displacement_cc': input.engineDisplacementCc,
          'catalog_source': input.catalogSource,
          'catalog_make_id': input.catalogMakeId,
          'catalog_model_id': input.catalogModelId,
          'is_primary': existing.isEmpty,
        })
        .select()
        .single();
    if (input.makePrimary && existing.isNotEmpty) {
      await setPrimary(row['motorcycle_id'] as String);
      row = await _client
          .from('motorcycles')
          .select()
          .eq('motorcycle_id', row['motorcycle_id'] as String)
          .eq('user_id', _userId)
          .single();
    }
    _notifyChanged();
    return Motorcycle.fromJson(row);
  }

  Future<void> setPrimary(String motorcycleId) async {
    await _client.rpc(
      'set_primary_motorcycle',
      params: {'p_motorcycle_id': motorcycleId},
    );
    _notifyChanged();
  }

  Future<Motorcycle> updateMotorcycle({
    required String motorcycleId,
    required String? nickname,
    required String make,
    required String model,
    required int modelYear,
    String type = 'other',
    int? engineDisplacementCc,
    String? catalogSource,
    int? catalogMakeId,
    int? catalogModelId,
    bool makePrimary = false,
  }) async {
    final row = await _client
        .from('motorcycles')
        .update({
          'nickname': _nullIfEmpty(nickname),
          'make': make.trim(),
          'model': model.trim(),
          'model_year': modelYear,
          'motorcycle_type': type,
          'engine_displacement_cc': engineDisplacementCc,
          'catalog_source': catalogSource,
          'catalog_make_id': catalogMakeId,
          'catalog_model_id': catalogModelId,
        })
        .eq('motorcycle_id', motorcycleId)
        .eq('user_id', _userId)
        .select()
        .single();
    if (makePrimary && row['is_primary'] != true) {
      await setPrimary(motorcycleId);
      final refreshed = await _client
          .from('motorcycles')
          .select()
          .eq('motorcycle_id', motorcycleId)
          .eq('user_id', _userId)
          .single();
      _notifyChanged();
      return Motorcycle.fromJson(refreshed);
    }
    _notifyChanged();
    return Motorcycle.fromJson(row);
  }

  Future<Motorcycle> saveElmAdapter({
    required String motorcycleId,
    required String deviceName,
    required String deviceIdentifier,
    required ElmTransport transport,
    bool autoConnect = true,
  }) async {
    final row = await _client
        .from('motorcycles')
        .update({
          'elm_device_name': deviceName.trim(),
          'elm_device_identifier': deviceIdentifier,
          'elm_transport': transport.databaseValue,
          'elm_auto_connect': autoConnect,
        })
        .eq('motorcycle_id', motorcycleId)
        .eq('user_id', _userId)
        .select()
        .single();
    _notifyChanged();
    return Motorcycle.fromJson(row);
  }

  Future<void> markElmConnected(String motorcycleId) async {
    await _client
        .from('motorcycles')
        .update({
          'last_elm_connected_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('motorcycle_id', motorcycleId)
        .eq('user_id', _userId);
    _notifyChanged();
  }

  Future<void> removeElmAdapter(String motorcycleId) async {
    await _client
        .from('motorcycles')
        .update({
          'elm_device_name': null,
          'elm_device_identifier': null,
          'elm_transport': null,
          'elm_auto_connect': false,
        })
        .eq('motorcycle_id', motorcycleId)
        .eq('user_id', _userId);
    _notifyChanged();
  }

  Future<void> deleteMotorcycle(String motorcycleId) async {
    await _client
        .from('motorcycles')
        .delete()
        .eq('motorcycle_id', motorcycleId)
        .eq('user_id', _userId);
    final remaining = await fetchMotorcycles();
    if (remaining.isNotEmpty && !remaining.any((bike) => bike.isPrimary)) {
      await setPrimary(remaining.first.id);
    }
    _notifyChanged();
  }

  void _notifyChanged() => changes.value++;

  static String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
