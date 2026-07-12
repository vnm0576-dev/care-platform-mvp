import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';

class RegistrationResult {
  const RegistrationResult({required this.needsEmailConfirmation});

  final bool needsEmailConfirmation;
}

abstract interface class AuthGateway {
  Future<RegistrationResult> signUp(AuthRegistrationRequest request);

  Future<AppRole> signIn({required String email, required String password});

  Future<void> signOut();
}
