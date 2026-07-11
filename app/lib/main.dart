import 'package:care_platform_app/app.dart';
import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/core/config/supabase_bootstrap.dart';
import 'package:care_platform_app/features/auth/data/supabase_auth_gateway.dart';
import 'package:care_platform_app/features/auth/data/unavailable_auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/client/data/supabase_client_request_gateway.dart';
import 'package:care_platform_app/features/client/data/unavailable_client_request_gateway.dart';
import 'package:care_platform_app/features/client/domain/client_request_gateway.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  Object? initializationError;

  try {
    await SupabaseBootstrap.initialize(config);
  } on Object catch (error) {
    initializationError = error;
  }

  final AuthGateway authGateway =
      config.isConfigured && initializationError == null
      ? SupabaseAuthGateway(Supabase.instance.client)
      : const UnavailableAuthGateway();

  final ClientRequestGateway clientRequestGateway =
      config.isConfigured && initializationError == null
      ? SupabaseClientRequestGateway(Supabase.instance.client)
      : const UnavailableClientRequestGateway();

  runApp(
    CarePlatformApp(
      config: config,
      authGateway: authGateway,
      clientRequestGateway: clientRequestGateway,
      initializationError: initializationError,
    ),
  );
}
