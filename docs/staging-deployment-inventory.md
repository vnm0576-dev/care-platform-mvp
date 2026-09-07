# Российский staging: инвентаризация исходного кода — этап 0, Issue #73

## 1. Назначение и границы доказательств

Это **source-level inventory**, а не отчёт о развёрнутом российском staging, сертификация исходящего трафика или разрешение на обработку реальных ПДн. Основание — [AGENTS.md](../AGENTS.md), [канонический handoff](project-handoff.md), [README](../README.md), [правила работы](agent-workflow.md), [Supabase README](../supabase/README.md) и [Flutter README](../app/README.md).

Просмотрены отслеживаемые исходники [Flutter](../app/lib), Android/Web-конфигурация, dependency manifests/lockfile, все миграции и локальные SQL-раннеры. Не исследованы живые серверы, настройки облачного аккаунта, содержимое production-БД, скомпилированный сетевой трафик и внутренности всех транзитивных SDK. Наличие зависимости не означает её активное использование; отсутствие вызова в приложении не доказывает отсутствие фонового обращения SDK/движка/ОС.

**Итог:** текущий активный backend-контракт — Supabase Auth + PostgREST + PostgreSQL RLS/RPC. Storage и Realtime присутствуют в графе зависимостей, но прикладные сценарии их не вызывают. Российская топология, private S3, SMTP/SMS, backup/PITR и узкий API для Hermes — целевые компоненты, не готовые deployment-артефакты этого репозитория. Compose/IaC и конфигурация реального staging здесь ещё не поставлены.

Реализованы регистрация/вход, анкета сиделки, поиск клиентом одобренных анкет, создание заявки и модерация анкет администратором. **Назначений сиделки семье, адресной выдачи контактов, этапов concierge-кейса и аудита выдачи контактов пока нет.** Стратегия concierge в handoff не превращает текущий каталог в назначение.

## 2. Конфигурация и полный прикладной Supabase-контракт

[main.dart](../app/lib/main.dart) подключает пять Supabase gateway после успешной инициализации; иначе используются `Unavailable*Gateway`, без поддельных успешных записей. [AppConfig](../app/lib/core/config/app_config.dart) читает compile-time `SUPABASE_URL` и `SUPABASE_ANON_KEY`. [Bootstrap](../app/lib/core/config/supabase_bootstrap.dart) вызывает точно:

```dart
await Supabase.initialize(
  url: config.supabaseUrl.trim(),
  publishableKey: config.supabaseAnonKey.trim(),
);
```

URL допускает HTTPS на любом хосте либо HTTP только для `localhost`, `127.0.0.1`, `::1`. География/allowlist доменов не проверяются. Блокируются `sb_secret_` и распознанные JWT с ролью `service_role`; это эвристика, не криптографическая проверка ключа. Public key извлекаем из сборки по определению; privileged key запрещён во Flutter независимо от этой проверки.

### 2.1. Auth и роль

Источник всех SDK-вызовов: [SupabaseAuthGateway](../app/lib/features/auth/data/supabase_auth_gateway.dart).

| Операция | Точный текущий вызов/чтение | Данные и назначение |
|---|---|---|
| Регистрация | `auth.signUp(email: request.email.trim(), password: request.password, data: request.metadata)` | Email, пароль; metadata: `full_name`, `role`, необязательный `phone` |
| Вход | `auth.signInWithPassword(email: email.trim(), password: password)` | Затем `from('profiles').select('role').eq('id', user.id).single()` |
| Восстановление роли | `auth.currentUser`, затем тот же `profiles.select('role')` | Роль берётся из БД, не из изменяемой пользовательской metadata |
| Выход | `auth.signOut()` | Scope в коде не переопределён |
| События | `auth.onAuthStateChange.map(...)` | Это поток Auth SDK, **не** подписка на PostgreSQL Realtime |

[AuthRegistrationRequest](../app/lib/features/auth/domain/auth_registration_request.dart) обрезает пробелы в имени/телефоне и допускает в UI только `caregiver`/`client`. [Экран регистрации](../app/lib/features/auth/presentation/registration_screen.dart) требует ФИО, email, пароль не короче восьми символов и локальную галочку правил; телефон необязателен. При `response.session == null` показывает просьбу подтвердить email и затем войти. При полученной session сразу маршрутизирует по выбранной роли; последующая загрузка роли использует БД.

[Вход](../app/lib/features/auth/presentation/login_screen.dart) и [app.dart](../app/lib/app.dart) разделяют экраны по ролям. После неуспешного role lookup при явном входе выполняется sign-out. При `currentRole()` сессия очищается для `ArgumentError` или `PostgrestException` с `PGRST116`, но не для любой временной ошибки; приложение при восстановлении может сохранить ранее известную роль. Поэтому маршрут UI не заменяет серверные проверки.

`initialSession`, `passwordRecovery`, `tokenRefreshed`, `userUpdated`, `mfaChallengeVerified` отображаются в `sessionUpdated`; это **не реализация** восстановления пароля или MFA. Прикладных вызовов OAuth, magic link, SMS OTP, MFA enrollment/challenge, reset/update password и удаления аккаунта нет. `emailRedirectTo`, кастомные Auth options, local storage и параметры refresh в bootstrap не заданы. Проверить фактические SDK defaults, сохранение/очистку токенов и callback URL нужно на PoC. В [Android manifest](../app/android/app/src/main/AndroidManifest.xml) нет отдельного Auth callback intent-filter.

### 2.2. Анкета сиделки

Источник: [SupabaseCaregiverProfileGateway](../app/lib/features/caregiver/data/supabase_caregiver_profile_gateway.dart), [payload](../app/lib/features/caregiver/domain/caregiver_profile.dart), [экран](../app/lib/features/caregiver/presentation/caregiver_profile_screen.dart).

| Операция | Цепочка вызовов |
|---|---|
| Своя анкета | `from('caregiver_profiles').select(_readFields).eq('profile_id', userId).maybeSingle()` |
| Новый черновик | `from('caregiver_profiles').insert({...payload, 'profile_id': auth.currentUser.id}).select(_readFields).single()` |
| Изменение | `from('caregiver_profiles').update(payload).eq('id', existingProfileId).select(_readFields).single()` |
| Отправка | `rpc('submit_caregiver_profile', params: {'p_caregiver_profile_id': caregiverProfileId})` |

`_readFields` точно: `id,status,rejection_reason,full_name,city,district,contact_phone,experience,education,certificates,skills,schedule,description,desired_payment,ready_for_live_in,ready_for_night_shifts,dementia_experience,bedridden_experience,stroke_experience,heart_attack_experience,trauma_experience`.

Payload содержит `full_name`, `city`, `contact_phone`, `experience`, `schedule`, `description` (пустая строка → null); `certificates`, `skills` (trim и удаление пустых элементов); перечисленные семь boolean-полей; `district`/`education` только если непустые, `desired_payment` только если не null. `photo_url`, статусы и причины модерации не отправляются. Экран редактирует имя, город, телефон, опыт, график, описание и навыки; остальные загруженные значения сохраняет. При отправке сначала сохраняет черновик, затем вызывает RPC: это два запроса, не единая транзакция. UPDATE фильтруется по ID, а принадлежность и актуальная редактируемость обеспечиваются RLS. `.single()` не позволяет считать нулевое обновление успешным.

### 2.3. Клиентский поиск и заявка

[Поисковый gateway](../app/lib/features/client/data/supabase_caregiver_search_gateway.dart):

```dart
from('approved_caregiver_profiles')
  .select('id,full_name,city,experience,schedule,description,contact_phone,approved_at')
  .ilike('city', exactCityPattern(city))
  .not('approved_at', 'is', null)
```

`exactCityPattern` делает trim и экранирует `\`, `%`, `_`, `*`: поиск города без намеренного wildcard, без учёта регистра. При курсоре добавляется `.or('approved_at.lt.$timestamp,and(approved_at.eq.$timestamp,id.lt.${cursor.id})')`, время UTC ISO-8601. Затем `.order('approved_at', ascending: false).order('id', ascending: false).limit(pageSize + 1)`. [Экран](../app/lib/features/client/presentation/client_caregiver_search_screen.dart) использует `pageSize = 20`. Город входит в URL query PostgREST и может попасть в access-логи.

После последней миграции `contact_phone` в этом ответе всегда SQL NULL; mapper превращает его в `''`, UI не показывает телефон/кнопку копирования. Условный `Clipboard.setData(...)` в UI остался для непустого телефона; телефонная интеграция/вызов dialer не реализованы. **Проекция доступна всем авторизованным клиентам, а не только назначенной семье.** Она также доступна admin; обычная сиделка её не читает. Имя, описание и другие открытые поля не обезличены, свободный текст способен содержать контакты вопреки редактированию отдельной колонки.

[Gateway заявки](../app/lib/features/client/data/supabase_client_request_gateway.dart) выполняет только:

```dart
from('client_requests')
  .insert({...request.toWritePayload(), 'profile_id': userId})
  .select('id').single()
```

[Payload заявки](../app/lib/features/client/domain/client_request.dart): `city,care_type,description,contact_phone` с trim; `needs_live_in,needs_night_shifts,dementia_case,bedridden_case,stroke_case,heart_attack_case,trauma_case`. Эти флаги и обязательное «Описание ситуации» действительно собираются [экраном](../app/lib/features/client/presentation/client_request_screen.dart), а не просто зарезервированы в БД. Нет загрузки/редактирования списка заявок во Flutter, idempotency key и workflow назначения. Кнопка заявки доступна из пустого результата поиска; сообщение о возможности дополнить её позднее не означает, что такой экран уже есть.

### 2.4. Административная модерация

[SupabaseAdminModerationGateway](../app/lib/features/admin/data/supabase_admin_moderation_gateway.dart) читает `from('caregiver_profiles').select(...)` со списком: `id,full_name,city,contact_phone,experience,certificates,skills,schedule,description,desired_payment,ready_for_live_in,ready_for_night_shifts,dementia_experience,bedridden_experience,stroke_experience,heart_attack_experience,trauma_experience,district,education,photo_url,submitted_at` и `.eq('status', 'pending_review')`.

Курсор: `.or('submitted_at.gt.$timestamp,and(submitted_at.eq.$timestamp,id.gt.${cursor.id})')`; сортировка `submitted_at ASC, id ASC`, `limit(pageSize + 1)`. [Экран](../app/lib/features/admin/presentation/admin_moderation_screen.dart) задаёт 20 и после решения перезагружает очередь, без Realtime.

Решение: `rpc('moderate_caregiver_profile', params: {'p_caregiver_profile_id': caregiverProfileId, 'p_new_status': newStatus.databaseValue, 'p_reason': reason.trim(), 'p_comment': comment?.trim()})`. UI предлагает только `approved`/`rejected` и обязательную причину; comment через экран не вводится. SQL дополнительно умеет hide/restore, но соответствующего UI нет. Flutter не читает `moderation_logs`, не вызывает `bootstrap_admin`, не модерирует клиентские заявки.

## 3. Схема, роли, миграции и переносимость

### 3.1. Полная последовательность миграций

Применять в порядке [Supabase README](../supabase/README.md), не переносить только последнюю view и не копировать тестовые Auth-фикстуры в staging.

| Миграция | Что переносится / изменяется |
|---|---|
| [20260710160000_initial_schema.sql](../supabase/migrations/20260710160000_initial_schema.sql) | `pgcrypto`, пять таблиц, FK/CHECK, timestamp triggers и индексы |
| [20260710161000_profile_statuses.sql](../supabase/migrations/20260710161000_profile_statuses.sql) | Идемпотентные строки `draft,pending_review,approved,rejected,hidden` через `ON CONFLICT` |
| [20260710162000_rls_policies.sql](../supabase/migrations/20260710162000_rls_policies.sql) | RLS всех пяти таблиц, column grants, `is_admin`, submit/moderate RPC |
| [20260710163000_auth_foundation.sql](../supabase/migrations/20260710163000_auth_foundation.sql) | Trigger `auth.users` → `profiles`, запрет клиентского INSERT профиля |
| [20260712115500_caregiver_profile_editability.sql](../supabase/migrations/20260712115500_caregiver_profile_editability.sql) | Owner UPDATE только `draft/rejected`, USING и WITH CHECK |
| [20260712130000_require_meaningful_caregiver_skills.sql](../supabase/migrations/20260712130000_require_meaningful_caregiver_skills.sql) | Meaningful-skills helper, CHECK/submit, перевод невалидных approved в rejected |
| [20260712140000_repair_legacy_meaningful_skills.sql](../supabase/migrations/20260712140000_repair_legacy_meaningful_skills.sql) | Forward-repair для ранее применённой проверки с ошибочным btrim для tabs/newlines |
| [20260712150000_repair_hidden_meaningful_skills.sql](../supabase/migrations/20260712150000_repair_hidden_meaningful_skills.sql) | Невалидные hidden → rejected, очистка hidden/approved metadata |
| [20260713100000_harden_profile_text_and_visibility.sql](../supabase/migrations/20260713100000_harden_profile_text_and_visibility.sql) | `has_visible_text`, repair profiles/анкет, усиление CHECK и Auth/submit, промежуточное ограничение чтения |
| [20260713110000_restrict_caregiver_projection_and_admin_bootstrap.sql](../supabase/migrations/20260713110000_restrict_caregiver_projection_and_admin_bootstrap.sql) | Проекция каталога; raw-анкеты только owner/admin; защищённый bootstrap admin |
| [20260817110000_redact_caregiver_contact_phone.sql](../supabase/migrations/20260817110000_redact_caregiver_contact_phone.sql) | Последнее определение проекции: `null::text as contact_phone`, сохранён контракт ответа |

Repair-миграции реально меняют legacy-данные; это не только DDL. Переопределение helper само по себе не перевалидирует старые строки, поэтому repairs нельзя пропускать. Финальную безопасность определяет вся цепочка, не первоначальная RLS-политика.

### 3.2. Объекты данных и финальный доступ

Источники: [initial schema](../supabase/migrations/20260710160000_initial_schema.sql), [RLS](../supabase/migrations/20260710162000_rls_policies.sql), последние переопределения в таблице выше.

| Объект | Данные/связи | Финальные прикладные права |
|---|---|---|
| `auth.users` | Штатный Supabase Auth; UUID, email/phone/metadata используются триггером | Не создаётся миграциями приложения; полный Auth lifecycle принадлежит GoTrue |
| `public.profiles` | Один профиль с тем же UUID, имя/email/phone/роль, timestamps; FK к Auth `ON DELETE CASCADE` | SELECT свой/admin; UPDATE имени/email/телефона свой/admin. Нет клиентского INSERT, DELETE или изменения role |
| `caregiver_profiles` | Одна анкета на profile_id; контакты, описание, опыт/навыки/сертификаты, стоимость, флаги, photo_url, статусы/причины/timestamps | Raw SELECT owner/admin; INSERT своей draft для caregiver; UPDATE разрешённых колонок owner только draft/rejected. Нет прямого изменения статуса или клиентского DELETE |
| `client_requests` | Несколько заявок на клиента; телефон, география, свободный текст, потребности и health-флаги; также district/preferred_schedule/desired_payment, не записываемые текущим UI | SELECT owner/admin; INSERT своего клиента; UPDATE допустимых колонок и DELETE owner. Админское чтение разрешено SQL, но отдельного UI заявок нет |
| `profile_statuses` | Справочник статусов с флагами видимости | Все authenticated читают, не пишут. Флаги справочника сами по себе не заменяют RLS |
| `moderation_logs` | Анкета, admin UUID, old/new status, reason/comment, timestamps | SELECT только admin; запись через moderation RPC, не прямой клиентский INSERT/UPDATE/DELETE |
| `approved_caregiver_profiles` | View с восемью колонками из поиска, телефон NULL | SELECT authenticated с внутренней проверкой роли client/admin и status approved; не выдаёт profile_id и moderation metadata |

Прикладные роли `caregiver/client/admin` — значения `profiles.role`, не отдельные PostgreSQL login roles. Составные FK `(profile_id, profile_role)` и `(admin_profile_id, admin_role)` с CHECK-discriminator защищают соответствие роли даже вне Flutter/RLS. Удаление Auth-пользователя каскадирует профиль и его анкеты/заявки; удаление анкеты каскадирует журнал модерации. FK на модератора — `ON DELETE RESTRICT`, поэтому удаление admin может блокироваться журналом. Это не готовая политика retention/уничтожения.

Anon не получает доступ к прикладным таблицам/view. RLS включена на пяти таблицах, но не `FORCE ROW LEVEL SECURITY`; владельцы объектов и privileged-роли требуют отдельного контроля. View использует `security_barrier = true, security_invoker = false`: доступ через владельца с явным фильтром `auth.uid()`/роль. При restore критично сохранить правильного владельца view и функции; нельзя механически переключить view в invoker, не проверив совместимость с запретом raw-чтения для клиента.

### 3.3. Функции, триггеры и привилегии

| Функция | Контракт и ограничения |
|---|---|
| `is_admin()` | SQL STABLE SECURITY DEFINER, проверяет profiles по `auth.uid()`, EXECUTE authenticated, PUBLIC отозван |
| `submit_caregiver_profile(uuid)` | SECURITY DEFINER, `FOR UPDATE`, auth/owner check, только draft/rejected → pending_review, проверка обязательного видимого текста и meaningful skills; очищает rejection metadata; EXECUTE authenticated |
| `moderate_caregiver_profile(uuid,text,text,text default null)` | SECURITY DEFINER, admin check, обязательная reason, row lock; pending_review → approved/rejected, approved → hidden, hidden → approved; изменение и moderation_log атомарны; EXECUTE authenticated |
| `handle_new_auth_user()` | SECURITY DEFINER trigger AFTER INSERT `on_auth_user_created` на auth.users. Требует значимое имя и role caregiver/client; phone metadata с fallback к Auth phone; атомарный INSERT profiles. EXECUTE отозван у PUBLIC/anon/authenticated |
| `bootstrap_admin(uuid)` | SECURITY DEFINER, только существующий выделенный профиль без анкеты/заявок; EXECUTE service_role, не authenticated/anon/PUBLIC. Не вызывается Flutter |
| `has_visible_text(text)` | SQL IMMUTABLE STRICT, regex `[^[:space:]]`, не SECURITY DEFINER; EXECUTE authenticated/service_role, PUBLIC отозван |
| `has_meaningful_caregiver_skills(text[])` | SQL IMMUTABLE STRICT, непустой массив без null и whitespace-only элементов; не SECURITY DEFINER. В текущих миграциях нет явного REVOKE EXECUTE у PUBLIC для этого helper |
| `set_updated_at()` | Обычная trigger-функция перед UPDATE каждой из пяти таблиц; `clock_timestamp()`, не SECURITY DEFINER; явного REVOKE EXECUTE в миграциях нет |

Все перечисленные определения задают пустой `search_path`. Не следует обобщать отзыв PUBLIC для защищённых RPC на все функции схемы. Moderation reason/comment в исходном RPC используют `btrim`; более поздний visible-text hardening не переписывает этот RPC или все текстовые CHECK заявок/журнала.

Auth-триггер работает только на INSERT: изменение `raw_user_meta_data` не повышает роль и автоматически не синхронизирует профиль; существующие до триггера пользователи не backfill-ятся. Restore должен сохранять UUID и зависимости, а не регистрировать пользователей заново. Bootstrap выполнять только в доверенном серверном контуре, без передачи service_role приложению; после повышения войти заново.

**Расширения:** единственный явный `CREATE EXTENSION` приложения — `pgcrypto`; UUID-default использует `gen_random_uuid()`. `uuid-ossp`, `pgjwt`, логическая репликация/публикации/слоты не требуются текущими прикладными миграциями. Они могут понадобиться выбранному self-hosted stack: это отдельная проверка, не утверждение об отсутствии системных зависимостей. `security_invoker` view option также требует совместимой версии PostgreSQL.

Миграции ожидают уже существующие Supabase `auth.users`, `auth.uid()`, роли `anon/authenticated/service_role`. `authenticator`, `supabase_admin` и иные служебные роли/владельцы выбираемого стека не создаются приложением. Для VM/DBaaS нужно отдельно доказать restore ролей, GRANT, ALTER DEFAULT PRIVILEGES, ALTER OWNER, SET ROLE, JWT claims, pooler и системных схем. Managed PostgreSQL не объявляется drop-in заменой.

## 4. Storage, Realtime, SDK и сетевые границы

Прямые зависимости [pubspec.yaml](../app/pubspec.yaml): Flutter, `cupertino_icons`, `supabase_flutter: ^2.16.0`; dev — flutter_test/flutter_lints. [Lockfile](../app/pubspec.lock) фиксирует `supabase_flutter 2.16.0`, `supabase 2.14.0`, `gotrue 2.26.0`, `postgrest 2.8.0`, `storage_client 2.6.0`, `realtime_client 2.11.0`, `functions_client 2.6.4`. Это версии данного среза, не заявление об актуальных upstream-релизах.

| Граница | Наблюдается в исходниках | Что не доказано / требуется |
|---|---|---|
| Flutter → Supabase endpoint | Auth, table/view queries, два прикладных RPC | Реальный DNS/TLS, расположение Auth/API/БД, redirects, HTTP headers и server logs |
| Storage API → S3 | Нет `.storage`, upload/download/signed URL вызовов, buckets или policies на storage.objects в миграциях | Private S3 — будущий инфраструктурный PoC. Не включать загрузку реальных документов |
| Фото/сертификаты | `photo_url` — текст в схеме, admin читает и отображает через `Text('Фото: ...')`; certificates — `text[]` | Это не загрузка/показ сетевой картинки и не проверка документов; схема не задаёт URL allowlist |
| Realtime/WebSocket | Транзитивные realtime_client, web_socket/web_socket_channel; нет channel/subscribe/database-stream вызовов | Не требуется для текущей очереди/поиска. Если оставить сервис в Compose, отдельно закрыть/проверить его endpoints и репликацию |
| Edge Functions | functions_client транзитивно; прикладного invoke нет, серверных функций в дереве нет | Не считать существующим узкий API Hermes или webhook boundary |
| Auth persistence/deep links | Транзитивные shared_preferences, app_links, url_launcher; bootstrap не задаёт собственное хранение | Проверить фактические token storage, browser storage, backup устройства, очистку при выходе и callback allowlist. Наличие пакета не доказывает OAuth/OTP use |
| Analytics/crash/push/support | Нет прикладного подключения Firebase Analytics, Crashlytics, Sentry, Amplitude, Mixpanel, push, платежей, карт, Telegram/Hermes/LLM API | Это не runtime no-egress сертификат; проверить SDK/движок/ОС и будущие серверные defaults |
| Web assets | [index.html](../app/web/index.html) загружает относительный `flutter_bootstrap.js`, локальные icon/manifest paths | Генерируемый bootstrap, renderer/WASM/fonts/CDN, CSP, кеши и service worker проверять в собранном release, а не выводить отсутствие egress из HTML |
| Android | [MainActivity](../app/android/app/src/main/kotlin/dev/vnm0576/care_platform_app/MainActivity.kt) — FlutterActivity; [main manifest](../app/android/app/src/main/AndroidManifest.xml) INTERNET, cleartext false; [debug override](../app/android/app/src/debug/AndroidManifest.xml) cleartext true | Нужен merged release manifest, проверка устройства/эмулятора, local storage и системных backup/clipboard границ; localhost устройства не localhost разработчика |
| Сборка/CI | pub.dev в lockfile; [Gradle](../app/android/build.gradle.kts) google/mavenCentral, [plugin repositories](../app/android/settings.gradle.kts), [Gradle distribution](../app/android/gradle/wrapper/gradle-wrapper.properties); [GitHub Actions](../.github/workflows/ci.yml) | Это supply-chain/build traffic, не необходимый runtime API. В GitHub только код/синтетика; production-сборка и secrets — отдельный защищённый контур |

CI собирает **ненастроенные** Web/AAB без Supabase dart-defines, Android с одноразовой CI-подписью, не публикует их. [Release signing](../app/android/app/build.gradle.kts) требует отдельной конфигурации и не подставляет debug key. Build success не подтверждает Auth/SMTP/S3 или географию трафика.

## 5. Данные и privacy gaps — стоп-факторы реального пилота

1. **Здоровье уже в форме заявки.** `dementia_case`, `bedridden_case`, `stroke_case`, `heart_attack_case`, `trauma_case` и обязательный свободный текст — активный сбор потенциально специальных ПДн, несмотря на более узкую желаемую границу handoff. Для PoC только синтетика. До реальных семей отдельно минимизировать форму/схему и согласовать основания обработки; функциональные потребности тоже могут раскрывать здоровье.
2. **Согласия не реализованы как доказательства.** `_acceptedTerms` — локальное состояние UI, не отправляется в Auth metadata/БД. Нет отдельных документов/версий/snapshot/hash, подписанта, отзыва, проверки представительства родственника или согласия на распространение анкеты. Общая галочка не закрывает требования handoff; юридическая достаточность устанавливается профильным специалистом.
3. **Каталог остаётся широким.** Любой зарегистрированный client получает одобренные имена/описания/опыт/график по городу. Redaction защищает конкретную phone-колонку, но не делает данные анонимными, не ограничивает их назначением и не очищает контакты в свободном тексте. Перед пилотом требуется отдельное решение о видимости, минимизации и согласиях.
4. **Concierge не реализован.** Нет сущностей назначения/подопечного/представителя, allowlisted transitions кейса, адресного contact RPC, журнала чтений, отзыва доступа после задания. Нельзя выдавать существующую модерацию анкет за модерацию заявок или сопровождение первого выхода.
5. **Логи и ошибки.** [Экран анкеты](../app/lib/features/caregiver/presentation/caregiver_profile_screen.dart) и [экран заявки](../app/lib/features/client/presentation/client_request_screen.dart) вставляют `$error` в SnackBar. Ошибки БД могут раскрыть детали строки/запроса в UI и скриншотах. Серверная redaction/retention конфигурация отсутствует; нужны нейтральные сообщения и запрет payload/tokens/OTP/passwords/signed URL в логах и support exports.
6. **Хранение не ограничено основной БД.** Auth metadata и public.profiles дублируют контакты; WAL/dumps/backups, клиентские токены, браузерные кеши, email, access-логи и операторские выгрузки входят в data inventory. Нет исполняемых процедур retention/удаления аккаунта/отзыва согласия; каскады и RESTRICT журнала требуют отдельного проектирования, а не ручного удаления production-строк.
7. **Аудит неполон.** moderation_logs фиксирует решения, но не чтения и выдачу контактов; при удалении анкеты каскадно удаляется. Bootstrap и repair-обновления не являются moderation RPC и не создают такие записи. Нельзя называть этот журнал неизменяемым общесистемным security audit.
8. **Администрирование.** MFA, rate limits, refresh rotation policy, закрытый Studio/БД, KMS, network policies и incident runbook описаны как требования в handoff, но не обеспечиваются прикладным кодом этого среза.

Правовые/ИБ gates и ответственные определяются по [handoff](project-handoff.md) и [release readiness](rustore-release-readiness.md); этот документ не перепроверяет актуальность законодательства, тарифов или аттестаций провайдера.

## 6. Обязательная матрица верификации staging

Ни одна строка ниже не объявлена пройденной на живом российском staging. Для каждой проверки сохранить commit/версии образов, среду, дату, исполнителя, ожидаемый/фактический результат и обезличенное доказательство. Сырые токены, письма с OTP и реальные строки БД в Issue/CI не прикладывать.

| Проверка | Сценарий и критерий приёмки | Необходимое доказательство |
|---|---|---|
| Локальная регрессия | Все команды из README: schema/RLS/Auth/layout, Flutter analyze/test/web; AAB отдельно | Вывод команд и exit codes. Это нижний уровень, не замена следующим строкам |
| Чистый stack/миграции | Штатный self-hosted Auth, затем вся цепочка; сверить пять таблиц, view, triggers, constraints, statuses | Version manifest, migration ledger, обезличенный schema diff; без подмены auth.users fixture |
| Roles/owners/restore | Restore synthetic roles/schema/data с прежними UUID, владельцами view/functions, grants/default privileges; проверить SET ROLE и pooler | Воспроизводимый runbook и ACL/owner diff до/после; реальный JWT → auth.uid(), не только SQL session setting |
| Регистрация | Caregiver/client с email confirmation, без немедленной session; отдельный сценарий с session если включён | Письмо через согласованный тестовый SMTP, подтверждение → вход → правильный profiles UUID/role; ошибочная metadata/admin rejected атомарно |
| Auth lifecycle | Перезапуск, refresh/expiry, sign-out, смена пользователя, временная сеть, отсутствующий/невалидный profile; recovery/MFA явно отделить как не реализованные UI | Результаты Web и Android, очистка локальной сессии, отсутствие доступа старого пользователя, безопасные сообщения |
| Привилегии | Аноним, два caregiver, два client, admin; прямые REST-запросы мимо UI | Чужие rows/колонки недоступны; client не читает raw-анкету, caregiver не читает каталог; нельзя менять role/status, писать logs или вызвать bootstrap с user JWT |
| Submit/edit lifecycle | Draft → submit; неполные/whitespace/null skills, чужой ID, повторный submit, stale edit pending/approved/hidden | Отказы сервера; `.single()` не маскирует UPDATE 0; rejected снова редактируется |
| Модерация | Все допустимые SQL-переходы, запрещённые переходы, non-admin, гонка двух решений | Атомарная status+log транзакция, отсутствие лишних logs при отказе; UI отдельно только approve/reject |
| Каталог/redaction | Поиск города с `%`, `_`, `*`, `\`, регистром; страницы с одинаковым approved_at; все доступные роли | Без дублей на границе курсора, только approved; `contact_phone = null` в REST, нет raw metadata и телефона в UI; отдельно проверить текстовые обходы |
| Заявка | Синтетическая заявка со всеми flags; foreign profile_id и role mismatch; owner update/delete через REST | Запись своей заявки и возврат id; изоляция от других клиентов/сиделок. Повтор после сетевого timeout оценить на дубликаты |
| Runtime egress | Cold start, signup/login/refresh, ошибки, поиск, submit/moderation на release Web/Android | Очищенный список DNS/HTTPS/WSS destinations и назначений, включая renderer/fonts/SDK; нет необъяснённых endpoints. Снять отдельно серверный egress |
| TLS/secrets/perimeter | Проверка домена, redirect allowlist/CORS, HTTPS-only release; Studio/DB/metrics/backups только private/VPN | Network rules и отрицательные connectivity tests; в сборке только public key; секреты вне Git/CI/Telegram |
| Private Storage PoC | Отдельный синтетический объект через Storage API → private S3; без включения медицинских файлов в приложение | Запрет anonymous/cross-user access, короткий signed URL/expiry, delete/lifecycle и environment isolation; policies ещё предстоит поставить |
| Realtime | Выключить/не публиковать неиспользуемый endpoint; при обоснованном включении проверить JWT/private channels/replication | Документированное решение и отдельные отрицательные тесты; Auth events продолжают работать без прикладных подписок |
| Backup/restore drill | Отдельный этап: encrypted backup + WAL/PITR, потеря disposable staging и полное восстановление | Реальные измеренные RPO/RTO, Auth/RLS/RPC и Storage consistency после restore; география и доступ к копиям подтверждены |
| Privacy/operations | Минимизация, согласия/представитель, retention, read audit, MFA admin, incident response | Согласованный design и проверяемые процедуры до любых реальных пользователей, не только галочки в отчёте |

[run_local.sh](../supabase/tests/run_local.sh) использует узкую schema-цепочку и минимальную auth.users; [run_auth_tests.sh](../supabase/tests/run_auth_tests.sh) — Auth fixture и цепочку до bootstrap; [run_rls_tests.sh](../supabase/tests/run_rls_tests.sh) включает последнюю redaction-миграцию. [004_deployable_migrations_test.sh](../supabase/tests/004_deployable_migrations_test.sh) проверяет имена/число/порядок файлов, **не поднимает stack и не применяет SQL**. Их успешное выполнение не доказывает GoTrue, SMTP, S3, полный cluster restore или PostgreSQL-совместимость конкретного провайдера.

## 7. Внешние prerequisites и следующий ограниченный Issue

### Что требует отдельного решения пользователя до российского staging

- Облачный аккаунт, согласованный бюджет/лимит расходов и ответственный за эксплуатацию. Yandex Cloud и Selectel — кандидаты из handoff, не проверенный этим inventory выбор и не подтверждение текущих услуг/цен.
- Российские VM/сеть и доступы: application stack, отдельная private PostgreSQL VM, VPN/bastion, закрытое администрирование; без Kubernetes на этом этапе.
- Домен/DNS/TLS, разрешённые redirects и endpoints; safe delivery только public key во Flutter.
- Согласованные версии upstream self-hosted Compose/образов и способ обновления; служебные роли/секреты, Secret Manager/KMS, rotation и ответственные. Не просить передавать secrets в чат.
- Российский SMTP с тестовой доставкой; SMS пока не нужен текущему email/password UI, подключать только при отдельном требовании, договоре и совместимом Auth-пути.
- Private S3, отдельные credentials/buckets по средам, российские логи/monitoring и backup-контур с restore drill.
- Подтверждение границ обработки/доступа поддержки, договоров и юридических/ИБ gates перед реальными данными. Сам факт размещения VM в РФ их не закрывает.

### Следующая безопасная задача: подготовка локального synthetic-only PoC

**Отдельный небольшой Issue/PR:** подготовить воспроизводимый локальный self-hosted Supabase PoC по выбранной upstream Compose-основе, с зафиксированными версиями, placeholders вместо secrets, loopback/private-only портами, отключёнными необязательными внешними сервисами и инструкцией start/stop/cleanup. Подготовить только вымышленных пользователей/анкеты/заявки и локальный mail sink без внешней доставки; расписать применение полной migration chain и Auth/REST smoke/negative проверки из матрицы. Если инструментов для реального локального прогона нет, явно зафиксировать блокер и не объявлять PoC работающим.

Критерий завершения этой следующей задачи: воспроизводимая подготовка и, в доступной изолированной локальной среде, зафиксированный synthetic smoke run; список оставшихся инфраструктурных вопросов. **Не** создание платного облака, не production restore, не импорт реальных ПДн, не изменение бизнес-схемы/concierge workflow и не объявление российского deployment завершённым. Private S3-интеграция и destructive backup/restore drill — отдельные последующие задачи. Оплачиваемые ресурсы, реальные домены и выдача доступов останавливаются до решения пользователя.
