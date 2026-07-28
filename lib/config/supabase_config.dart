class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jnshyvmwjxqspxqrprqr.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_EWTUxIJfBKgXFQTzKzgzfQ_NTtkyBH7',
  );

  static const authRedirectUrl = 'io.motomap.app://login-callback/';

  static bool get isConfigured => publishableKey.trim().isNotEmpty;
}
