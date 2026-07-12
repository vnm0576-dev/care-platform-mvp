import 'package:care_platform_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('is not configured when both values are absent', () {
      const config = AppConfig(supabaseUrl: '', supabaseAnonKey: '');

      expect(config.isConfigured, isFalse);
    });

    test('is not configured when only one value is present', () {
      const missingKey = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: '',
      );
      const missingUrl = AppConfig(
        supabaseUrl: '',
        supabaseAnonKey: 'publishable-anon-key',
      );

      expect(missingKey.isConfigured, isFalse);
      expect(missingUrl.isConfigured, isFalse);
    });

    test('accepts a valid HTTPS Supabase URL and publishable key', () {
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'publishable-anon-key',
      );

      expect(config.isConfigured, isTrue);
    });

    test('rejects a malformed Supabase URL', () {
      const config = AppConfig(
        supabaseUrl: 'not-a-url',
        supabaseAnonKey: 'publishable-anon-key',
      );

      expect(config.isConfigured, isFalse);
    });

    test('rejects non-local HTTP Supabase URLs', () {
      const config = AppConfig(
        supabaseUrl: 'http://care-platform.example',
        supabaseAnonKey: 'publishable-anon-key',
      );

      expect(config.isConfigured, isFalse);
    });

    test('accepts loopback HTTP only for local Supabase development', () {
      const localhost = AppConfig(
        supabaseUrl: 'http://localhost:54321',
        supabaseAnonKey: 'local-anon-key',
      );
      const loopback = AppConfig(
        supabaseUrl: 'http://127.0.0.1:54321',
        supabaseAnonKey: 'local-anon-key',
      );

      expect(localhost.isConfigured, isTrue);
      expect(loopback.isConfigured, isTrue);
    });

    test('rejects a Supabase secret key', () {
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'sb_secret_a_real_secret_must_not_be_shipped',
      );

      expect(config.isConfigured, isFalse);
    });

    test('rejects a legacy service-role JWT', () {
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature',
      );

      expect(config.isConfigured, isFalse);
    });
  });
}
