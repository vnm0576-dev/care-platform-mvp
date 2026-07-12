import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<RegistrationResult> signUp(AuthRegistrationRequest request) async {
    final response = await _client.auth.signUp(
      email: request.email.trim(),
      password: request.password,
      data: request.metadata,
    );
    return RegistrationResult(needsEmailConfirmation: response.session == null);
  }

  @override
  Future<AppRole> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException(
        'Supabase did not return an authenticated user',
      );
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      return AppRole.fromDatabaseValue(profile['role'] as String);
    } on Object {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
