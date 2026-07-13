# Care Platform MVP

Учебно-боевой MVP для связи сиделок, клиентов и администраторов: сиделка создаёт анкету → администратор модерирует её → клиент видит только одобренные анкеты и получает способ связи.

## Что уже есть

- Flutter-приложение с регистрацией, входом, анкетой сиделки, поиском одобренных анкет, клиентской заявкой и экраном модерации;
- Supabase/PostgreSQL-схема с ролями, RLS, Auth-триггером, защищёнными RPC-переходами статусов и журналом модерации;
- локальные исполняемые проверки схемы, RLS, регистрации и развёртываемого порядка миграций.

Границы MVP: без встроенной оплаты, чата, рейтингов, медицинских документов и автоматической проверки документов. Полный функциональный объём: [docs/mvp-scope.md](docs/mvp-scope.md).

## Быстрый маршрут для следующего разработчика

1. Прочитай [app/README.md](app/README.md): требования Flutter, безопасная конфигурация Supabase и команды запуска.
2. Прочитай [supabase/README.md](supabase/README.md): порядок миграций, RLS и локальная проверка PostgreSQL.
3. Перед изменением прикладного кода или схемы создай отдельный GitHub Issue, ветку и PR. Процесс: [docs/agent-workflow.md](docs/agent-workflow.md).

## Проверенная локальная база данных

Нужны PostgreSQL client/server tools и passwordless локальный доступ через системную учётную запись `postgres`.

Из корня репозитория:

```bash
./supabase/tests/run_local.sh
./supabase/tests/run_rls_tests.sh
./supabase/tests/run_auth_tests.sh
./supabase/tests/004_deployable_migrations_test.sh
```

Раннеры создают одноразовые базы, добавляют минимальные Supabase Auth-фикстуры, применяют миграции и удаляют базы после проверок. Они не подключаются к размещённому Supabase-проекту.

## Flutter: установка и проверка

Нужен Flutter stable, совместимый с Dart SDK `^3.12.2` из `app/pubspec.yaml`.

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build web
```

Без настроенного Supabase приложение запускается в безопасном диагностическом состоянии:

```bash
flutter run -d chrome
```

Для реального подключения передавай только URL проекта и public/publishable key во время сборки. Не записывай ключи в репозиторий и никогда не используй `service_role` в мобильном приложении:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Подробности о транспортной безопасности, допустимых ключах и Android: [app/README.md](app/README.md).

## Развёртывание Supabase

Миграции находятся в [supabase/migrations](supabase/migrations). Они предполагают штатную Supabase-таблицу `auth.users`; не создавай и не заменяй её вручную. Точный порядок применения, включая forward-repair для уже применённой старой проверки навыков, указан в [supabase/README.md](supabase/README.md).

Перед подключением Flutter к размещённому проекту нужно:

1. создать и защитить Supabase-проект;
2. применить миграции через стандартный процесс Supabase;
3. создать обычную учётную запись через приложение, затем в **Supabase Dashboard → SQL Editor** от имени владельца проекта назначить ей роль администратора. Подставь UUID этой учётной записи из **Authentication → Users**:

```sql
update public.profiles
set role = 'admin'
where id = 'UUID_УЧЁТНОЙ_ЗАПИСИ';
```

   Не используй `service_role` в приложении и не разрешай регистрацию с ролью `admin`: этот однократный bootstrap выполняется только в Dashboard/через доверенный серверный контур. После изменения войди этой учётной записью заново.
4. проверить регистрацию сиделки и клиента, отправку анкеты, вход администратора, модерацию и видимость одобренной анкеты в реальном проекте;
5. отдельно собрать bundle с теми же параметрами Supabase и проверить его на Android-устройстве:

```bash
cd app
flutter build appbundle \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

## Уровни верификации

Сейчас в репозитории проверяются локально: PostgreSQL-схема, RLS/права, Auth-фикстуры, миграционный порядок и Flutter-тесты/сборка при наличии Flutter SDK.

Не следует считать локальные SQL-раннеры или успешную Flutter-сборку доказательством реальной интеграции с hosted Supabase. Развёрнутый проект, реальные Auth-сценарии и Android-артефакт требуют отдельной проверки с доступом к соответствующей инфраструктуре.

## Документация

- [Документация MVP](docs/)
- [Схема данных](docs/database-schema.md)
- [Поток анкеты сиделки](docs/caregiver-profile-flow.md)
- [Поток поиска клиента](docs/client-search-flow.md)
- [Поток модерации](docs/admin-moderation-flow.md)
- [Технический стек](docs/tech-stack.md)
