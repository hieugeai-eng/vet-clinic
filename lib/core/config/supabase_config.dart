/// Supabase credentials configuration
///
/// Uses compile-time constants via --dart-define
/// Build with:
///   flutter run --dart-define-from-file=.env.local
///   flutter build windows --dart-define-from-file=.env.local
///
/// SECURITY: Keys are embedded in binary (not a separate file)
/// This is safer than shipping a .env file alongside the app
class SupabaseConfig {
  /// Project URL from Supabase dashboard
  static const projectUrl = String.fromEnvironment('SUPABASE_URL');

  /// Anon/public API key from Supabase dashboard
  /// WARNING: This MUST be the anon key (role=anon), NOT service_role key!
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Clinic ID (tenant identifier)
  static const clinicId = String.fromEnvironment('CLINIC_ID');

  /// Tenant schema name (derived from clinic ID)
  static String get tenantSchema =>
      clinicId.isNotEmpty ? 'tenant_${clinicId.replaceAll('-', '_')}' : '';

  /// REST API base URL
  static String get restUrl => '$projectUrl/rest/v1';

  /// Realtime WebSocket URL
  static String get realtimeUrl {
    final base = projectUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base/realtime/v1/websocket';
  }

  /// Check if credentials are configured
  static bool get isConfigured => projectUrl.isNotEmpty && anonKey.isNotEmpty;

  /// Check if tenant is configured
  static bool get hasTenant => clinicId.isNotEmpty;
}
