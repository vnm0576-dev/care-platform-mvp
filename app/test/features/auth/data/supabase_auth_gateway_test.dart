import 'package:care_platform_app/features/auth/data/supabase_auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('transient role lookup errors preserve the saved session', () {
    expect(
      SupabaseAuthGateway.shouldClearSessionAfterRoleLookupError(
        Exception('temporary network failure'),
      ),
      isFalse,
    );
  });

  test('a definitively missing profile clears the saved session', () {
    expect(
      SupabaseAuthGateway.shouldClearSessionAfterRoleLookupError(
        const PostgrestException(
          message: 'JSON object requested, multiple (or no) rows returned',
          code: 'PGRST116',
        ),
      ),
      isTrue,
    );
  });

  test('an invalid stored role clears the saved session', () {
    expect(
      SupabaseAuthGateway.shouldClearSessionAfterRoleLookupError(
        ArgumentError.value('unknown', 'role'),
      ),
      isTrue,
    );
  });
}
