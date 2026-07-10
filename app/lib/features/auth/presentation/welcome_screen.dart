import 'package:care_platform_app/core/config/app_config.dart';
import 'package:care_platform_app/navigation/app_routes.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.config,
    this.initializationError,
    super.key,
  });

  final AppConfig config;
  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    final ready = config.isConfigured && initializationError == null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.volunteer_activism_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Платформа заботы',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Связь сиделок и семей, которым требуется надёжная помощь.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  if (!ready)
                    _SetupNotice(initializationError: initializationError)
                  else ...[
                    FilledButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.login),
                      child: const Text('Войти'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.register),
                      child: const Text('Зарегистрироваться'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({this.initializationError});

  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    final hasError = initializationError != null;

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(hasError ? Icons.error_outline : Icons.settings_outlined),
            const SizedBox(height: 12),
            Text(
              hasError
                  ? 'Не удалось инициализировать Supabase'
                  : 'Настройка Supabase не завершена',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasError
                  ? 'Проверьте URL и publishable anon key.'
                  : 'Передайте SUPABASE_URL и SUPABASE_ANON_KEY через --dart-define.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
