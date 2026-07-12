import 'package:care_platform_app/app.dart';
import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/core/config/supabase_bootstrap.dart';
import 'package:care_platform_app/features/admin/data/supabase_admin_moderation_gateway.dart';
import 'package:care_platform_app/features/admin/data/unavailable_admin_moderation_gateway.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';
import 'package:care_platform_app/features/auth/data/supabase_auth_gateway.dart';
import 'package:care_platform_app/features/auth/data/unavailable_auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/caregiver/data/supabase_caregiver_profile_gateway.dart';
import 'package:care_platform_app/features/caregiver/data/unavailable_caregiver_profile_gateway.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';
import 'package:care_platform_app/features/client/data/supabase_caregiver_search_gateway.dart';
import 'package:care_platform_app/features/client/data/supabase_client_request_gateway.dart';
import 'package:care_platform_app/features/client/data/unavailable_caregiver_search_gateway.dart';
import 'package:care_platform_app/features/client/data/unavailable_client_request_gateway.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';
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
  final CaregiverProfileGateway caregiverGateway =
      config.isConfigured && initializationError == null
      ? SupabaseCaregiverProfileGateway(Supabase.instance.client)
      : const UnavailableCaregiverProfileGateway();
  final CaregiverSearchGateway caregiverSearchGateway =
      config.isConfigured && initializationError == null
      ? SupabaseCaregiverSearchGateway(Supabase.instance.client)
      : const UnavailableCaregiverSearchGateway();
  final ClientRequestGateway clientRequestGateway =
      config.isConfigured && initializationError == null
      ? SupabaseClientRequestGateway(Supabase.instance.client)
      : const UnavailableClientRequestGateway();
  final AdminModerationGateway adminModerationGateway =
      config.isConfigured && initializationError == null
      ? SupabaseAdminModerationGateway(Supabase.instance.client)
      : const UnavailableAdminModerationGateway();

  runApp(
    CarePlatformApp(
      config: config,
      authGateway: authGateway,
      caregiverGateway: caregiverGateway,
      caregiverSearchGateway: caregiverSearchGateway,
      clientRequestGateway: clientRequestGateway,
      adminModerationGateway: adminModerationGateway,
      initializationError: initializationError,
    ),
  );
}
