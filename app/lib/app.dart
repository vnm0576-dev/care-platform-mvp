import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/core/theme/app_theme.dart';
import 'package:care_platform_app/features/auth/presentation/auth_placeholder_screen.dart';
import 'package:care_platform_app/features/auth/presentation/welcome_screen.dart';
import 'package:care_platform_app/features/caregiver/presentation/caregiver_placeholder_screen.dart';
import 'package:care_platform_app/features/client/presentation/client_placeholder_screen.dart';
import 'package:care_platform_app/navigation/app_routes.dart';
import 'package:flutter/material.dart';

class CarePlatformApp extends StatelessWidget {
  const CarePlatformApp({
    required this.config,
    this.initializationError,
    super.key,
  });

  final AppConfig config;
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
        AppRoutes.login: (_) => const AuthPlaceholderScreen(title: 'Вход'),
        AppRoutes.register: (_) =>
            const AuthPlaceholderScreen(title: 'Регистрация'),
        AppRoutes.caregiver: (_) => const CaregiverPlaceholderScreen(),
        AppRoutes.client: (_) => const ClientPlaceholderScreen(),
      },
    );
  }
}
