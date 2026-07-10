import 'package:care_platform_app/app.dart';
import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const configuredAppConfig = AppConfig(
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'publishable-anon-key',
  );

  testWidgets('shows safe setup state when Supabase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarePlatformApp(
        config: const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
        authGateway: _FakeAuthGateway(),
      ),
    );

    expect(find.text('Платформа заботы'), findsOneWidget);
    expect(find.text('Настройка Supabase не завершена'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Войти'), findsNothing);
  });

  testWidgets('shows auth actions when Supabase configuration is valid', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarePlatformApp(
        config: configuredAppConfig,
        authGateway: _FakeAuthGateway(),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Зарегистрироваться'),
      findsOneWidget,
    );
  });

  testWidgets('opens the login form from the welcome screen', (tester) async {
    await tester.pumpWidget(
      CarePlatformApp(
        config: configuredAppConfig,
        authGateway: _FakeAuthGateway(),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Вход'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
  });

  testWidgets('submits validated credentials to the auth gateway', (
    tester,
  ) async {
    final gateway = _FakeAuthGateway();
    await tester.pumpWidget(
      CarePlatformApp(config: configuredAppConfig, authGateway: gateway),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'caregiver@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secure-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(gateway.email, 'caregiver@example.com');
    expect(gateway.password, 'secure-pass');
  });
}

class _FakeAuthGateway implements AuthGateway {
  String? email;
  String? password;

  @override
  Future<RegistrationResult> signUp(AuthRegistrationRequest request) async {
    return const RegistrationResult(needsEmailConfirmation: false);
  }

  @override
  Future<AppRole> signIn({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    return AppRole.caregiver;
  }
}
