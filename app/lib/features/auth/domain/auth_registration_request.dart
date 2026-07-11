enum AppRole {
  caregiver('caregiver'),
  client('client'),
  admin('admin');

  const AppRole(this.databaseValue);

  final String databaseValue;

  static const registrable = [AppRole.caregiver, AppRole.client];

  static AppRole fromDatabaseValue(String value) {
    return switch (value) {
      'caregiver' => AppRole.caregiver,
      'client' => AppRole.client,
      'admin' => AppRole.admin,
      _ => throw ArgumentError.value(value, 'value', 'Unsupported app role'),
    };
  }
}

class AuthRegistrationRequest {
  const AuthRegistrationRequest({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });

  final String fullName;
  final String email;
  final String phone;
  final String password;
  final AppRole role;

  Map<String, String> get metadata {
    final result = <String, String>{
      'full_name': fullName.trim(),
      'role': role.databaseValue,
    };
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isNotEmpty) {
      result['phone'] = trimmedPhone;
    }
    return result;
  }
}
