class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isConfigured {
    final uri = Uri.tryParse(supabaseUrl.trim());
    final supportedScheme = uri?.scheme == 'https' || uri?.scheme == 'http';

    return supabaseAnonKey.trim().isNotEmpty &&
        uri != null &&
        supportedScheme &&
        uri.host.isNotEmpty;
  }
}
