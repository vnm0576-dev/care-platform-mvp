import 'package:care_platform_app/app.dart';
import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';
import 'package:care_platform_app/features/client/domain/client_request.dart';
import 'package:care_platform_app/features/client/domain/client_request_gateway.dart';
import 'package:care_platform_app/navigation/app_routes.dart';
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

  testWidgets('submits caregiver registration metadata to the auth gateway', (
    tester,
  ) async {
    final gateway = _FakeAuthGateway();
    await tester.pumpWidget(
      CarePlatformApp(config: configuredAppConfig, authGateway: gateway),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Зарегистрироваться'));
    await tester.pumpAndSettle();

    expect(find.text('Регистрация'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Я предлагаю услуги сиделки'), findsOneWidget);
    expect(find.text('Я ищу сиделку'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ирина Петрова');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'irina@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '+79990000000');
    await tester.enterText(find.byType(TextFormField).at(3), 'secure-pass-123');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    final submitButton = find.widgetWithText(FilledButton, 'Создать аккаунт');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(gateway.signUpRequest?.metadata, {
      'full_name': 'Ирина Петрова',
      'role': 'caregiver',
      'phone': '+79990000000',
    });
  });
  testWidgets('clears the welcome and login stack after successful sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarePlatformApp(
        config: configuredAppConfig,
        authGateway: _FakeAuthGateway(),
        caregiverGateway: _FakeCaregiverProfileGateway(),
      ),
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

    expect(find.text('Черновик анкеты сиделки'), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
  });

  testWidgets(
    'clears the welcome and registration stack after immediate signup',
    (tester) async {
      await tester.pumpWidget(
        CarePlatformApp(
          config: configuredAppConfig,
          authGateway: _FakeAuthGateway(),
          caregiverGateway: _FakeCaregiverProfileGateway(),
        ),
      );

      await _submitRegistration(tester);
      await tester.pumpAndSettle();

      expect(find.text('Черновик анкеты сиделки'), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    },
  );

  testWidgets('keeps the registration confirmation open until acknowledged', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarePlatformApp(
        config: configuredAppConfig,
        authGateway: _FakeAuthGateway(needsEmailConfirmation: true),
      ),
    );

    await _submitRegistration(tester);
    await tester.pump();

    expect(find.text('Подтвердите email'), findsOneWidget);
    await tester.tapAt(const Offset(1, 1));
    await tester.pump();

    expect(find.text('Подтвердите email'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Создать аккаунт'), findsNothing);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();

    expect(find.text('Платформа заботы'), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
  });

  testWidgets('opens the caregiver draft instead of the placeholder route', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarePlatformApp(
        config: configuredAppConfig,
        authGateway: _FakeAuthGateway(),
        caregiverGateway: _FakeCaregiverProfileGateway(),
      ),
    );

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.caregiver);
    await tester.pumpAndSettle();

    expect(find.text('Черновик анкеты сиделки'), findsOneWidget);
    expect(find.text('Раздел сиделки готов к реализации.'), findsNothing);
  });
  testWidgets('opens the client request instead of the placeholder route', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarePlatformApp(
        config: configuredAppConfig,
        authGateway: _FakeAuthGateway(),
        clientRequestGateway: _FakeClientRequestGateway(),
        caregiverSearchGateway: _FakeCaregiverSearchGateway(),
      ),
    );

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.client);
    await tester.pumpAndSettle();

    expect(find.text('Поиск сиделки'), findsOneWidget);
    expect(find.text('Найти сиделку'), findsOneWidget);
    expect(find.text('Заявка на подбор сиделки'), findsNothing);
  });
  testWidgets('opens the moderation queue for the administrator route', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarePlatformApp(
        config: configuredAppConfig,
        authGateway: _FakeAuthGateway(),
        adminModerationGateway: _FakeAdminModerationGateway(),
      ),
    );

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.admin);
    await tester.pumpAndSettle();

    expect(find.text('Модерация анкет'), findsOneWidget);
    expect(find.text('Анкеты ожидают модерации'), findsOneWidget);
  });
}

Future<void> _submitRegistration(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(OutlinedButton, 'Зарегистрироваться'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'Ирина Петрова');
  await tester.enterText(find.byType(TextFormField).at(1), 'irina@example.com');
  await tester.enterText(find.byType(TextFormField).at(2), '+79990000000');
  await tester.enterText(find.byType(TextFormField).at(3), 'secure-pass-123');
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  final submitButton = find.widgetWithText(FilledButton, 'Создать аккаунт');
  await tester.ensureVisible(submitButton);
  await tester.tap(submitButton);
}

class _FakeCaregiverSearchGateway implements CaregiverSearchGateway {
  @override
  Future<CaregiverSearchPage> loadApproved({
    required String city,
    required int page,
    required int pageSize,
  }) async => const CaregiverSearchPage(items: [], hasMore: false);
}

class _FakeAdminModerationGateway implements AdminModerationGateway {
  @override
  Future<PendingCaregiverProfilesPage> loadPending({
    required int page,
    required int pageSize,
  }) async => const PendingCaregiverProfilesPage(items: [], hasMore: false);

  @override
  Future<void> moderate({
    required String caregiverProfileId,
    required ModerationStatus newStatus,
    required String reason,
    String? comment,
  }) async {}
}

class _FakeClientRequestGateway implements ClientRequestGateway {
  @override
  Future<ClientRequestRecord> create(ClientRequestDraft request) async =>
      const ClientRequestRecord(id: 'request-1');
}

class _FakeCaregiverProfileGateway implements CaregiverProfileGateway {
  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() async => null;

  @override
  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  }) async => const CaregiverProfileRecord(
    id: 'caregiver-profile-1',
    status: CaregiverProfileStatus.draft,
  );

  @override
  Future<void> submitForReview(String caregiverProfileId) async {}
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.needsEmailConfirmation = false});

  final bool needsEmailConfirmation;
  String? email;
  String? password;
  AuthRegistrationRequest? signUpRequest;

  @override
  Future<RegistrationResult> signUp(AuthRegistrationRequest request) async {
    signUpRequest = request;
    return RegistrationResult(needsEmailConfirmation: needsEmailConfirmation);
  }

  @override
  Future<void> signOut() async {}

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
