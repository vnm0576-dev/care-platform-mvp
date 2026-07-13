# Care Platform — единый контекст проекта

**Актуальность:** 13 июля 2026 года  
**Канонический репозиторий:** `https://github.com/vnm0576-dev/care-platform-mvp`  
**Локальный путь:** `/home/ops/care-platform-mvp`

## 1. Цель

Care Platform помогает семьям находить проверенных сиделок для пожилых людей. Стратегический сценарий первого запуска — concierge-MVP:

1. семья оставляет заявку после выписки или при возникновении потребности в уходе;
2. координатор уточняет функциональные потребности и риски;
3. вручную выбирает 2–3 проверенных сиделок;
4. объясняет семье причины выбора;
5. организует и сопровождает первый выход;
6. собирает обратную связь и при необходимости меняет подбор.

Текущий программный MVP также поддерживает регистрацию, анкету сиделки, клиентский поиск и административную модерацию. Публичный каталог рассматривается как вспомогательный сценарий, а не как главная бизнес-модель запуска.

## 2. Что уже реализовано

- Flutter-приложение;
- роли `caregiver`, `client`, `admin`;
- регистрация и вход через Supabase Auth;
- анкета сиделки и жизненный цикл модерации;
- клиентская заявка и поиск одобренных анкет;
- административная модерация;
- PostgreSQL-схема и миграции;
- RLS;
- защищённые RPC и `SECURITY DEFINER`;
- журнал модерации;
- локальные тесты схемы, RLS, Auth и порядка развёртывания;
- Flutter unit/widget tests;
- GitHub Actions CI;
- Web- и Android-build paths.

Последний объединённый PR на момент документа: **PR #66**, ветка исправлений Codex объединена в `main`.

## 3. Текущие границы MVP

Не входят:

- встроенная оплата;
- публичный чат;
- рейтинги;
- медицинская диагностика;
- изменение назначений;
- телемедицинские консультации;
- загрузка медицинских выписок;
- автоматическая проверка документов;
- интерпретация показателей как медицинское заключение.

## 4. Зафиксированная целевая архитектура

### 4.1. Ближайший этап

Использовать self-hosted Supabase в российской инфраструктуре. Это сохраняет:

- `supabase_flutter`;
- пользователей и UUID `auth.users`;
- SQL-миграции;
- RLS и `auth.uid()`;
- PostgreSQL RPC;
- Storage API;
- большую часть Flutter-кода.

```text
Flutter
   │ HTTPS
   ▼
WAF / Load Balancer
   │
   ▼
API Gateway
   ├── Supabase Auth / GoTrue
   ├── PostgREST
   ├── Supabase Storage API ── private S3 в РФ
   └── Realtime, только если нужен
                  │
                  ▼
        PostgreSQL в private network
```

### 4.2. Начальная production-топология

- VM 1: Kong/API Gateway, GoTrue, PostgREST, Storage API;
- VM 2: PostgreSQL;
- private S3: фотографии и файлы;
- отдельный российский backup-контур;
- VPN/bastion для администрирования;
- KMS/Secret Manager;
- российские SMTP и SMS;
- self-hosted или российские monitoring/logging.

Публичными должны быть только необходимые HTTPS endpoints. PostgreSQL, Supabase Studio, metrics и backup storage публичными быть не должны.

### 4.3. Почему не Kubernetes сейчас

Официальный рекомендуемый self-hosting path Supabase — Docker Compose. Kubernetes Helm charts community-driven. Для одного MVP Kubernetes повышает стоимость и эксплуатационный риск. Его вводить после появления необходимости в rolling deployments, autoscaling, нескольких app nodes и HA.

### 4.4. Почему не Appwrite/PocketBase/Hasura

- Appwrite меняет модель БД, Auth, permissions и Flutter API;
- PocketBase использует SQLite, не сохраняет PostgreSQL RLS/RPC и не подходит для production-critical системы с чувствительными данными;
- Hasura потребует перехода на GraphQL и создаст второй слой permissions;
- собственный backend даёт контроль, но требует переписать Flutter data/auth layer.

Если полный отказ от Supabase станет обязательным, предпочтительная последовательность:

`Keycloak + PostgreSQL + PostgREST + российский S3/File API`.

## 5. Российские облака

### Основной shortlist

1. **Yandex Cloud** — первый PoC: зрелые IAM/KMS/Lockbox/Audit Trails, S3 SSE-KMS, развитая автоматизация и несколько российских зон.
2. **Selectel** — второй PoC: российские регионы, сильная VM-инфраструктура, PostgreSQL 15–17, PITR и защищённое облако до УЗ-1.
3. **Cloud.ru Evolution** — enterprise/security benchmark: Managed PostgreSQL, S3 SSE-KMS, УЗ-1, лицензии ФСТЭК/ФСБ.

VK Cloud рассматривать после письменного подтверждения состава защищённого контура для DBaaS/Kubernetes/S3 и KMS. MWS — после PoC PostgreSQL 18 и коммерческого расчёта.

### Ориентиры стоимости, не оферта

- Yandex Cloud MVP: примерно 12–20 тыс. ₽/мес.; HA: 30–55 тыс. ₽/мес.;
- Selectel MVP: примерно 10–19 тыс. ₽/мес.; HA: 23–45 тыс. ₽/мес.;
- Cloud.ru MVP: примерно 11–20 тыс. ₽/мес.; HA: 28–50 тыс. ₽/мес.

Не включены WAF/SOC/SIEM, сертифицированные СЗИ, защищённый сегмент, SMS/email, миграция, поддержка и работы по соответствию.

## 6. Ограничение Managed PostgreSQL

Managed PostgreSQL нельзя считать drop-in заменой Supabase Postgres. До выбора нужно проверить:

- роли `anon`, `authenticated`, `service_role`, `authenticator`, `supabase_admin`;
- `GRANT`, `ALTER DEFAULT PRIVILEGES`, `ALTER OWNER`, `SET ROLE`;
- RLS и JWT claims;
- `pgcrypto`, `uuid-ossp`, `pgjwt` и фактически используемые расширения;
- логическую репликацию для Realtime;
- connection pooler;
- полный restore roles/schema/data.

Поэтому на первом этапе PostgreSQL размещается на отдельной VM. Переход на DBaaS возможен только после воспроизводимого PoC и всех тестов.

## 7. Персональные данные и здоровье

Care Platform почти наверняка является оператором ПДн. Облачный провайдер и другие подрядчики обрабатывают данные по поручению, но ответственность оператора не исчезает.

Сведения о диагнозах, деменции, диабете, инвалидности, лекарствах, аллергиях, мобильности и потребности в уходе могут быть специальными категориями ПДн о состоянии здоровья по статье 10 152-ФЗ.

### Безопасная граница пилота

До юридической и ИБ-готовности:

- не загружать медицинские документы;
- не создавать медицинскую карту;
- не собирать полный диагноз и свободный клинический текст;
- не интерпретировать показатели;
- не изменять назначения;
- собирать минимальный функциональный профиль;
- предоставлять сиделке только необходимые для конкретного задания сведения.

Даже функциональные параметры могут косвенно характеризовать здоровье и требуют минимизации и защиты.

## 8. Согласия и представитель

С 1 сентября 2025 года согласие на ПДн оформляется отдельно от других подтверждаемых документов. Нужны раздельные:

- оферта;
- политика;
- обычное согласие на обработку;
- письменное согласие на сведения о здоровье;
- согласие сиделки на распространение конкретных полей;
- рекламное согласие, если появится реклама.

Одна общая галочка недостаточна.

Для электронной письменной формы требуется формализованная простая электронная подпись: подтверждённый аккаунт/телефон, OTP, точный snapshot документа, версия, hash, время, подписант и доказательство проверки.

Если заявку подаёт родственник, его согласие не всегда заменяет согласие подопечного. Нужно проверять доверенность, законное представительство и способность подопечного выразить волю.

## 9. Compliance минимум до production

- определить юридического оператора;
- назначить ответственного;
- составить data inventory и карту потоков;
- подать уведомление Роскомнадзору до начала обработки;
- оформить поручения подрядчикам;
- выполнить оценку вреда;
- разработать модель угроз;
- определить уровень защищённости ИСПДн;
- реализовать меры приказа ФСТЭК №21;
- провести оценку эффективности защиты;
- установить режим no cross-border;
- создать incident response: первичное уведомление 24 часа, расследование 72 часа;
- утвердить retention schedule;
- подтверждать уничтожение актом и журналом; подтверждения хранить 3 года;
- провести pentest API/RLS/Storage;
- провести restore drill.

Предварительно для специальных ПДн и менее 100 тыс. субъектов возможен УЗ-3 при угрозах третьего типа; если нельзя исключить угрозы второго типа — ориентир УЗ-2. Окончательно уровень определяется моделью угроз, а не тарифом облака.

Это инженерно-исследовательский вывод, а не индивидуальная юридическая консультация. До production требуется профильный российский юрист по 152-ФЗ/323-ФЗ.

## 10. Технические меры

### Auth и RLS

- MFA для администраторов;
- rotation refresh tokens;
- rate limits;
- RLS на каждой публикуемой таблице;
- `USING` и `WITH CHECK`;
- negative access tests;
- немедленный отзыв доступа сиделки после завершения назначения;
- privileged keys только в серверном контуре.

### `SECURITY DEFINER`

- фиксированный безопасный `search_path`;
- schema-qualified объекты;
- `EXECUTE` отозван у `PUBLIC`;
- проверка принадлежности объектов внутри функции;
- отсутствие произвольного `user_id` для действий от чужого имени;
- аудит чувствительных вызовов.

### Storage

- private buckets;
- короткие signed URL;
- отсутствие ФИО/диагнозов в именах;
- отдельные buckets и ключи по средам;
- antivirus quarantine;
- lifecycle и проверяемое удаление;
- аудит чтения чувствительных файлов.

### Логи

Не писать токены, OTP, пароли, диагнозы, полные payload, signed URL и паспортные данные.

Инженерный ориентир:

- debug: 7–30 дней;
- access: 90–180 дней;
- security/audit: 12–24 месяца;
- доказательства уничтожения: 3 года;
- согласия: по отдельной юридической retention policy.

## 11. Внешние сервисы

- GitHub/Codex можно использовать для исходного кода без production ПДн и секретов;
- production deployment — через self-hosted runner в РФ;
- не использовать зарубежные Firebase Analytics, Crashlytics, Sentry Cloud, Amplitude, Mixpanel и support SaaS без отдельного правового решения;
- push payload должен быть нейтральным, без ФИО, адреса, диагноза и текста заявки;
- Telegram — только обезличенные уведомления;
- production SMTP/SMS — российские процессоры с договорным поручением.

## 12. Hermes/СИИ

Hermes должен быть перенесён на отдельную российскую VM, если получает заявки, анкеты, письма клиентов или сведения о здоровье.

Он не должен иметь `service_role` или прямой доступ ко всей production-базе. Нужен узкий служебный API с минимальными операциями и аудитом.

## 13. План российского PoC

### Этап 0. Инвентаризация

- Supabase calls во Flutter;
- Auth flows;
- зависимости от `auth.users`;
- RLS/RPC/extensions;
- Storage и Realtime;
- внешние SDK и сетевые соединения.

### Этап 1. Российский staging

- self-hosted Supabase по официальному Docker Compose;
- собственный домен и TLS;
- закрытый Studio;
- российские SMTP/SMS;
- private S3;
- restore roles/schema/data;
- все SQL- и Flutter-тесты.

### Этап 2. Backup/restore

- PITR/WAL;
- encrypted backup;
- отдельная копия в РФ;
- уничтожение тестового staging;
- полное восстановление;
- фиксация фактических RPO/RTO.

### Этап 3. Закрытый concierge-пилот

- минимальные данные;
- ручной подбор;
- ограниченное число семей и сиделок;
- журналирование;
- критерии остановки при инциденте.

### Этап 4. HA

Только после реальной нагрузки: второй app node, replica/failover, SIEM, WAF высокого уровня, регулярный pentest.

## 14. Проверка репозитория

Из корня:

```bash
./supabase/tests/run_local.sh
./supabase/tests/run_rls_tests.sh
./supabase/tests/run_auth_tests.sh
./supabase/tests/004_deployable_migrations_test.sh
```

Flutter:

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build web
```

Отдельно проверить Android AAB. Тесты без реального российского deployment не доказывают работу hosted Auth, SMTP, S3 и backup.

## 15. Следующий безопасный шаг

Создать отдельный GitHub Issue для российского staging/PoC. Не менять текущую production-архитектуру одним большим коммитом. Разбить на:

1. deployment inventory;
2. Docker Compose staging;
3. secrets/domains/TLS;
4. database restore;
5. private S3;
6. security tests;
7. backup/restore drill;
8. Yandex Cloud versus Selectel decision record.

## 16. Основные источники

- 152-ФЗ: https://www.consultant.ru/document/cons_doc_LAW_61801/
- специальные категории: https://www.consultant.ru/document/cons_doc_LAW_61801/26edb2934b899bf9c74c3a8f7e574651c6565e6d
- уведомление Роскомнадзора: https://pd.rkn.gov.ru/operators-registry/notification
- трансграничная передача: https://pd.rkn.gov.ru/cross-border-transmission/form2
- инциденты: https://pd.rkn.gov.ru/incidents
- ПП РФ №1119: https://www.consultant.ru/document/cons_doc_LAW_137356/
- приказ ФСТЭК №21: https://fstec.ru/normotvorcheskaya/akty/53-prikazy/691-prikaz-fstek-rossii-ot-18-fevralya-2013-g-n-21
- 323-ФЗ, врачебная тайна: https://www.consultant.ru/document/cons_doc_LAW_121895/9f906d460f9454a8a0d290738d9fc2798c1e865a
- Supabase self-hosting: https://supabase.com/docs/guides/self-hosting
- Docker: https://supabase.com/docs/guides/self-hosting/docker
- S3 backend: https://supabase.com/docs/guides/self-hosting/self-hosted-s3
- Yandex Cloud 152-ФЗ: https://yandex.cloud/ru/solutions/152-fz
- Selectel 152-ФЗ: https://selectel.ru/services/cloud/servers/152fz
