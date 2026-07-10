import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates metadata accepted by the Auth-to-profile trigger', () {
    const request = AuthRegistrationRequest(
      fullName: 'Ирина Петрова',
      email: 'irina@example.com',
      phone: '+79990000000',
      password: 'secure-pass-123',
      role: AppRole.caregiver,
    );

    expect(request.metadata, {
      'full_name': 'Ирина Петрова',
      'role': 'caregiver',
      'phone': '+79990000000',
    });
  });

  test('does not send an empty phone number to Supabase metadata', () {
    const request = AuthRegistrationRequest(
      fullName: 'Сергей Иванов',
      email: 'sergey@example.com',
      phone: '  ',
      password: 'secure-pass-123',
      role: AppRole.client,
    );

    expect(request.metadata, {'full_name': 'Сергей Иванов', 'role': 'client'});
  });
}
