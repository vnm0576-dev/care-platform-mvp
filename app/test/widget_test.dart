import 'package:care_platform_app/app.dart';
import 'package:care_platform_app/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows safe setup state when Supabase is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CarePlatformApp(
        config: AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
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
      const CarePlatformApp(
        config: AppConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'publishable-anon-key',
        ),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Зарегистрироваться'),
      findsOneWidget,
    );
  });

  testWidgets('opens the login placeholder from the welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CarePlatformApp(
        config: AppConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'publishable-anon-key',
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Вход'), findsWidgets);
    expect(
      find.text('Экран будет реализован на следующем этапе.'),
      findsOneWidget,
    );
  });
}
