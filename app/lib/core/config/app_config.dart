import 'dart:convert';

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
    final key = supabaseAnonKey.trim();

    return key.isNotEmpty &&
        uri != null &&
        uri.host.isNotEmpty &&
        _isAllowedUrl(uri) &&
        !_isSecretKey(key);
  }

  bool _isAllowedUrl(Uri uri) {
    if (uri.scheme == 'https') {
      return true;
    }

    return uri.scheme == 'http' && _isLoopbackHost(uri.host);
  }

  bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  bool _isSecretKey(String key) {
    if (key.startsWith('sb_secret_')) {
      return true;
    }

    final parts = key.split('.');
    if (parts.length != 3) {
      return false;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      return decoded is Map && decoded['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }
}
