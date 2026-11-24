class AppEnvironment {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabaseUrl.contains('.supabase.co') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.startsWith('YOUR_');
}
