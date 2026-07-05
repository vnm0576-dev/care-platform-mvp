# Черновая схема базы данных

## users

Пользователи приложения.

Поля:

- id
- email
- phone
- role
- created_at

## caregiver_profiles

Анкеты сиделок.

Поля:

- id
- user_id
- full_name
- city
- experience
- skills
- schedule
- contact_phone
- description
- moderation_status

## client_requests

Заявки клиентов.

Поля:

- id
- user_id
- city
- care_type
- description
- contact_phone
- created_at

## moderation_status

Статусы модерации.

Возможные значения:

- draft
- pending
- approved
- rejected
- hidden
