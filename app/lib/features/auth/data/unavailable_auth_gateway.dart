import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';

class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway();

  @override
  Future<RegistrationResult> signUp(AuthRegistrationRequest request) {
    throw StateError('Supabase is not configured');
  }

  @override
  Future<AppRole> signIn({required String email, required String password}) {
    throw StateError('Supabase is not configured');
  }

  @override
  Future<void> signOut() {
    throw StateError('Supabase is not configured');
  }
}
