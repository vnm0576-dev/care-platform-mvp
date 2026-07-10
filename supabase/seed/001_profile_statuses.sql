insert into public.profile_statuses (
  code,
  title,
  description,
  visible_to_client,
  visible_to_caregiver,
  visible_to_admin
)
values
  (
    'draft',
    'Черновик',
    'Анкета создана, но ещё не отправлена на модерацию.',
    false, true, true
  ),
  (
    'pending_review',
    'Ожидает модерации',
    'Анкета отправлена сиделкой на проверку администратору.',
    false, true, true
  ),
  (
    'approved',
    'Опубликована',
    'Анкета одобрена администратором и доступна клиентам.',
    true, true, true
  ),
  (
    'rejected',
    'Отклонена',
    'Анкета отклонена администратором и требует исправления.',
    false, true, true
  ),
  (
    'hidden',
    'Скрыта',
    'Ранее опубликованная анкета скрыта администратором.',
    false, true, true
  )
on conflict (code) do update
set
  title = excluded.title,
  description = excluded.description,
  visible_to_client = excluded.visible_to_client,
  visible_to_caregiver = excluded.visible_to_caregiver,
  visible_to_admin = excluded.visible_to_admin;
