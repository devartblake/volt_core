// Central place for API-related constants.
// We’ll lean towards Supabase instead of a custom REST URL,
// but you can keep both if you’re in a migration phase.

class ApiConstants {
  /// Base URL for your Supabase project (e.g. https://xyz.supabase.co)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-supabase-project.supabase.co',
  );

  /// Public anon key for Supabase.
  /// In a real app make sure to:
  ///  - keep service role keys on backend only
  ///  - scope RLS correctly in Supabase
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'SUPABASE_ANON_KEY_HERE',
  );

  /// Optional REST API base (if you still talk to a backend).
  static const String restBaseUrl = String.fromEnvironment(
    'REST_BASE_URL',
    defaultValue: 'https://api.your-backend.com',
  );

  // Example table names for Supabase
  static const String inspectionsTable = 'inspections';
  static const String maintenanceTable = 'maintenance_jobs';
  static const String equipmentTable = 'equipment';
  static const String techniciansTable = 'technicians';
}