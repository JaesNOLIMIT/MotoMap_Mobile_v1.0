import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rider_profile.dart';

class ProfileService {
  ProfileService._();

  static final instance = ProfileService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<RiderProfile> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No authenticated rider.');

    final row = await _client
        .from('profiles')
        .select(
          'user_id, first_name, last_name, username, phone_number, birth_date, avatar_path',
        )
        .eq('user_id', user.id)
        .single();
    return RiderProfile.fromJson(row);
  }
}
