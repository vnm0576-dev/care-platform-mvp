import 'package:care_platform_app/app.dart';
import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/core/config/supabase_bootstrap.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  Object? initializationError;

  try {
    await SupabaseBootstrap.initialize(config);
  } on Object catch (error) {
    initializationError = error;
  }

  runApp(
    CarePlatformApp(config: config, initializationError: initializationError),
  );
}
