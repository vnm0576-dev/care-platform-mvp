import 'package:care_platform_app/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static Future<void> initialize(AppConfig config) async {
    if (!config.isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: config.supabaseUrl.trim(),
      publishableKey: config.supabaseAnonKey.trim(),
    );
  }
}
