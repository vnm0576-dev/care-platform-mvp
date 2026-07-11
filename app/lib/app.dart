import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/core/theme/app_theme.dart';
import 'package:care_platform_app/features/admin/presentation/admin_holding_screen.dart';
import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/auth/presentation/login_screen.dart';
import 'package:care_platform_app/features/auth/presentation/registration_screen.dart';
import 'package:care_platform_app/features/auth/presentation/welcome_screen.dart';
import 'package:care_platform_app/features/caregiver/data/unavailable_caregiver_profile_gateway.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';
import 'package:care_platform_app/features/caregiver/presentation/caregiver_profile_screen.dart';
import 'package:care_platform_app/features/client/data/unavailable_caregiver_search_gateway.dart';
import 'package:care_platform_app/features/client/data/unavailable_client_request_gateway.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';
import 'package:care_platform_app/features/client/domain/client_request_gateway.dart';
import 'package:care_platform_app/features/client/presentation/client_caregiver_search_screen.dart';
import 'package:care_platform_app/features/client/presentation/client_request_screen.dart';
import 'package:care_platform_app/navigation/app_routes.dart';
import 'package:flutter/material.dart';

class CarePlatformApp extends StatelessWidget {
  const CarePlatformApp({
    required this.config,
    required this.authGateway,
    this.caregiverGateway = const UnavailableCaregiverProfileGateway(),
    this.caregiverSearchGateway = const UnavailableCaregiverSearchGateway(),
    this.clientRequestGateway = const UnavailableClientRequestGateway(),
    this.initializationError,
    super.key,
  });

  final AppConfig config;
  final AuthGateway authGateway;
  final CaregiverProfileGateway caregiverGateway;
  final CaregiverSearchGateway caregiverSearchGateway;
  final ClientRequestGateway clientRequestGateway;
  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Платформа заботы',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.root,
      routes: {
        AppRoutes.root: (_) => WelcomeScreen(
          config: config,
          initializationError: initializationError,
        ),
        AppRoutes.login: (_) => LoginScreen(authGateway: authGateway),
        AppRoutes.register: (_) => RegistrationScreen(authGateway: authGateway),
        AppRoutes.admin: (_) => const AdminHoldingScreen(),
        AppRoutes.caregiver: (_) =>
            CaregiverProfileScreen(gateway: caregiverGateway),
        AppRoutes.client: (context) => ClientCaregiverSearchScreen(
          gateway: caregiverSearchGateway,
          onLeaveRequest: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ClientRequestScreen(gateway: clientRequestGateway),
            ),
          ),
        ),
      },
    );
  }
}
