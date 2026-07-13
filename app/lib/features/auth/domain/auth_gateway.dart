import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';

class RegistrationResult {
  const RegistrationResult({required this.needsEmailConfirmation});

  final bool needsEmailConfirmation;
}

abstract interface class AuthGateway {
  Future<RegistrationResult> signUp(AuthRegistrationRequest request);

  Future<AppRole> signIn({required String email, required String password});

  Future<AppRole?> currentRole();

  Future<void> signOut();
}

enum AuthSessionChange { signedIn, signedOut, sessionUpdated }

abstract interface class AuthStateAwareGateway {
  Stream<AuthSessionChange> get authStateChanges;
}
