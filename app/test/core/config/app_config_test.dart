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

    test('accepts a valid Supabase URL and anon key', () {
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

    test('accepts localhost HTTP for local Supabase development', () {
      const config = AppConfig(
        supabaseUrl: 'http://localhost:54321',
        supabaseAnonKey: 'local-anon-key',
      );

      expect(config.isConfigured, isTrue);
    });
  });
}
