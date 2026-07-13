import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthGateway implements AuthGateway, AuthStateAwareGateway {
  const SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthSessionChange> get authStateChanges => _client
      .auth
      .onAuthStateChange
      .map((data) => mapAuthChangeEvent(data.event));

  static AuthSessionChange mapAuthChangeEvent(AuthChangeEvent event) =>
      switch (event) {
        AuthChangeEvent.signedIn => AuthSessionChange.signedIn,
        AuthChangeEvent.signedOut => AuthSessionChange.signedOut,
        AuthChangeEvent.initialSession ||
        AuthChangeEvent.passwordRecovery ||
        AuthChangeEvent.tokenRefreshed ||
        AuthChangeEvent.userUpdated ||
        AuthChangeEvent.mfaChallengeVerified =>
          AuthSessionChange.sessionUpdated,
        _ => AuthSessionChange.signedOut,
      };

  static bool shouldClearSessionAfterRoleLookupError(Object error) {
    return error is ArgumentError ||
        error is PostgrestException && error.code == 'PGRST116';
  }

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

  @override
  Future<AppRole?> currentRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      return AppRole.fromDatabaseValue(profile['role'] as String);
    } on Object catch (error) {
      if (shouldClearSessionAfterRoleLookupError(error)) {
        await signOut();
      }
      rethrow;
    }
  }
}
