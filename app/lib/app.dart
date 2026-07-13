import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/core/theme/app_theme.dart';
import 'package:care_platform_app/features/admin/data/unavailable_admin_moderation_gateway.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';
import 'package:care_platform_app/features/admin/presentation/admin_moderation_screen.dart';
import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';
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

class CarePlatformApp extends StatefulWidget {
  const CarePlatformApp({
    required this.config,
    required this.authGateway,
    this.caregiverGateway = const UnavailableCaregiverProfileGateway(),
    this.caregiverSearchGateway = const UnavailableCaregiverSearchGateway(),
    this.clientRequestGateway = const UnavailableClientRequestGateway(),
    this.adminModerationGateway = const UnavailableAdminModerationGateway(),
    this.initializationError,
    super.key,
  });

  final AppConfig config;
  final AuthGateway authGateway;
  final CaregiverProfileGateway caregiverGateway;
  final CaregiverSearchGateway caregiverSearchGateway;
  final ClientRequestGateway clientRequestGateway;
  final AdminModerationGateway adminModerationGateway;
  final Object? initializationError;

  @override
  State<CarePlatformApp> createState() => _CarePlatformAppState();
}

class _CarePlatformAppState extends State<CarePlatformApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AppRole? _role;
  int _authGeneration = 0;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final generation = _authGeneration;
    AppRole? role;
    try {
      role = await widget.authGateway.currentRole();
    } on Object {
      role = null;
    }
    if (!mounted || generation != _authGeneration) return;
    setState(() {
      _role = role;
    });
    if (role != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _authGeneration || _role != role) return;
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.root,
          (route) => false,
        );
      });
    }
  }

  void _authenticated(AppRole role) {
    _authGeneration++;
    setState(() => _role = role);
  }

  Future<void> _signOut(BuildContext context) async {
    _authGeneration++;
    try {
      await widget.authGateway.signOut();
      if (!mounted || !context.mounted) return;
      setState(() => _role = null);
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.root, (route) => false);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось выйти')));
    }
  }

  Widget _root() {
    return switch (_role) {
      AppRole.caregiver => _caregiverScreen(),
      AppRole.client => _clientScreen(),
      AppRole.admin => _adminScreen(),
      null => WelcomeScreen(
        config: widget.config,
        initializationError: widget.initializationError,
      ),
    };
  }

  Widget _caregiverScreen() => Builder(
    builder: (context) => CaregiverProfileScreen(
      gateway: widget.caregiverGateway,
      onSignOut: () => _signOut(context),
    ),
  );

  Widget _clientScreen() => Builder(
    builder: (context) => ClientCaregiverSearchScreen(
      gateway: widget.caregiverSearchGateway,
      onSignOut: () => _signOut(context),
      onLeaveRequest: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ClientRequestScreen(gateway: widget.clientRequestGateway),
        ),
      ),
    ),
  );

  Widget _adminScreen() => Builder(
    builder: (context) => AdminModerationScreen(
      gateway: widget.adminModerationGateway,
      onSignOut: () => _signOut(context),
    ),
  );

  Widget _guarded(AppRole requiredRole, Widget Function() screen) {
    if (_role != requiredRole) {
      return WelcomeScreen(
        config: widget.config,
        initializationError: widget.initializationError,
      );
    }
    return screen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Платформа заботы',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.root,
      routes: {
        AppRoutes.root: (_) => _root(),
        AppRoutes.login: (_) => LoginScreen(
          authGateway: widget.authGateway,
          onAuthenticated: _authenticated,
        ),
        AppRoutes.register: (_) => RegistrationScreen(
          authGateway: widget.authGateway,
          onAuthenticated: _authenticated,
        ),
        AppRoutes.admin: (_) => _guarded(AppRole.admin, _adminScreen),
        AppRoutes.caregiver: (_) =>
            _guarded(AppRole.caregiver, _caregiverScreen),
        AppRoutes.client: (_) => _guarded(AppRole.client, _clientScreen),
      },
    );
  }
}
