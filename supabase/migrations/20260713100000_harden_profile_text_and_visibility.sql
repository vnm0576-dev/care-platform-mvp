begin;

create or replace function public.has_visible_text(value text)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select value ~ '[^[:space:]]';
$$;

revoke all on function public.has_visible_text(text) from public;
grant execute on function public.has_visible_text(text) to authenticated;

alter table public.profiles
  drop constraint profiles_full_name_not_blank_check,
  drop constraint profiles_email_not_blank_check,
  drop constraint profiles_phone_not_blank_check;

alter table public.caregiver_profiles
  drop constraint caregiver_profiles_full_name_not_blank_check,
  drop constraint caregiver_profiles_city_not_blank_check,
  drop constraint caregiver_profiles_district_not_blank_check,
  drop constraint caregiver_profiles_contact_phone_not_blank_check,
  drop constraint caregiver_profiles_experience_not_blank_check,
  drop constraint caregiver_profiles_education_not_blank_check,
  drop constraint caregiver_profiles_schedule_not_blank_check,
  drop constraint caregiver_profiles_description_not_blank_check,
  drop constraint caregiver_profiles_photo_url_not_blank_check,
  drop constraint caregiver_profiles_rejection_reason_not_blank_check,
  drop constraint caregiver_profiles_hidden_reason_not_blank_check,
  drop constraint caregiver_profiles_approved_fields_check;

update public.profiles
set
  full_name = case
    when not public.has_visible_text(full_name) then 'Пользователь'
    else full_name
  end,
  email = case
    when email is not null and not public.has_visible_text(email) then null
    else email
  end,
  phone = case
    when phone is not null and not public.has_visible_text(phone) then null
    else phone
  end;

update public.caregiver_profiles
set
  full_name = case when full_name is not null and not public.has_visible_text(full_name) then null else full_name end,
  city = case when city is not null and not public.has_visible_text(city) then null else city end,
  district = case when district is not null and not public.has_visible_text(district) then null else district end,
  contact_phone = case when contact_phone is not null and not public.has_visible_text(contact_phone) then null else contact_phone end,
  experience = case when experience is not null and not public.has_visible_text(experience) then null else experience end,
  education = case when education is not null and not public.has_visible_text(education) then null else education end,
  schedule = case when schedule is not null and not public.has_visible_text(schedule) then null else schedule end,
  description = case when description is not null and not public.has_visible_text(description) then null else description end,
  photo_url = case when photo_url is not null and not public.has_visible_text(photo_url) then null else photo_url end,
  rejection_reason = case when rejection_reason is not null and not public.has_visible_text(rejection_reason) then null else rejection_reason end,
  hidden_reason = case when hidden_reason is not null and not public.has_visible_text(hidden_reason) then null else hidden_reason end;

update public.caregiver_profiles
set
  status = 'rejected',
  rejection_reason = 'Заполните обязательные поля анкеты значимым текстом',
  rejected_at = clock_timestamp(),
  hidden_reason = null,
  hidden_at = null
where status in ('approved', 'pending_review', 'hidden')
  and (
    not coalesce(public.has_visible_text(full_name), false)
    or not coalesce(public.has_visible_text(city), false)
    or not coalesce(public.has_visible_text(contact_phone), false)
    or not coalesce(public.has_visible_text(experience), false)
    or not coalesce(public.has_visible_text(schedule), false)
    or not public.has_meaningful_caregiver_skills(skills)
    or not coalesce(public.has_visible_text(description), false)
  );

alter table public.profiles
  add constraint profiles_full_name_not_blank_check
    check (public.has_visible_text(full_name)),
  add constraint profiles_email_not_blank_check
    check (email is null or public.has_visible_text(email)),
  add constraint profiles_phone_not_blank_check
    check (phone is null or public.has_visible_text(phone));

alter table public.caregiver_profiles
  add constraint caregiver_profiles_full_name_not_blank_check
    check (full_name is null or public.has_visible_text(full_name)),
  add constraint caregiver_profiles_city_not_blank_check
    check (city is null or public.has_visible_text(city)),
  add constraint caregiver_profiles_district_not_blank_check
    check (district is null or public.has_visible_text(district)),
  add constraint caregiver_profiles_contact_phone_not_blank_check
    check (contact_phone is null or public.has_visible_text(contact_phone)),
  add constraint caregiver_profiles_experience_not_blank_check
    check (experience is null or public.has_visible_text(experience)),
  add constraint caregiver_profiles_education_not_blank_check
    check (education is null or public.has_visible_text(education)),
  add constraint caregiver_profiles_schedule_not_blank_check
    check (schedule is null or public.has_visible_text(schedule)),
  add constraint caregiver_profiles_description_not_blank_check
    check (description is null or public.has_visible_text(description)),
  add constraint caregiver_profiles_photo_url_not_blank_check
    check (photo_url is null or public.has_visible_text(photo_url)),
  add constraint caregiver_profiles_rejection_reason_not_blank_check
    check (rejection_reason is null or public.has_visible_text(rejection_reason)),
  add constraint caregiver_profiles_hidden_reason_not_blank_check
    check (hidden_reason is null or public.has_visible_text(hidden_reason)),
  add constraint caregiver_profiles_approved_fields_check
    check (
      status <> 'approved'
      or (
        coalesce(public.has_visible_text(full_name), false)
        and coalesce(public.has_visible_text(city), false)
        and coalesce(public.has_visible_text(contact_phone), false)
        and coalesce(public.has_visible_text(experience), false)
        and coalesce(public.has_visible_text(schedule), false)
        and public.has_meaningful_caregiver_skills(skills)
        and coalesce(public.has_visible_text(description), false)
        and approved_at is not null
      )
    );

create or replace function public.submit_caregiver_profile(
  p_caregiver_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.caregiver_profiles%rowtype;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication is required';
  end if;

  select * into v_profile
  from public.caregiver_profiles
  where id = p_caregiver_profile_id
  for update;

  if not found or v_profile.profile_id <> v_user_id then
    raise exception using errcode = '42501', message = 'Caregiver profile does not belong to the current user';
  end if;

  if v_profile.status not in ('draft', 'rejected') then
    raise exception using errcode = '22023', message = 'Only draft or rejected profiles can be submitted';
  end if;

  if not coalesce(public.has_visible_text(v_profile.full_name), false)
     or not coalesce(public.has_visible_text(v_profile.city), false)
     or not coalesce(public.has_visible_text(v_profile.contact_phone), false)
     or not coalesce(public.has_visible_text(v_profile.experience), false)
     or not coalesce(public.has_visible_text(v_profile.schedule), false)
     or not public.has_meaningful_caregiver_skills(v_profile.skills)
     or not coalesce(public.has_visible_text(v_profile.description), false) then
    raise exception using errcode = '23514', message = 'Required caregiver profile fields are incomplete';
  end if;

  update public.caregiver_profiles
  set status = 'pending_review', submitted_at = clock_timestamp(), rejection_reason = null, rejected_at = null
  where id = p_caregiver_profile_id;
end;
$$;

revoke all on function public.submit_caregiver_profile(uuid) from public;
grant execute on function public.submit_caregiver_profile(uuid) to authenticated;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_full_name text := nullif(btrim(v_metadata ->> 'full_name'), '');
  v_role text := lower(nullif(btrim(v_metadata ->> 'role'), ''));
  v_phone text := coalesce(
    nullif(btrim(v_metadata ->> 'phone'), ''),
    nullif(btrim(new.phone), '')
  );
begin
  if not coalesce(public.has_visible_text(v_full_name), false) then
    raise exception using errcode = '22023', message = 'Registration metadata full_name is required';
  end if;

  if v_role is null or v_role not in ('caregiver', 'client') then
    raise exception using errcode = '22023', message = 'Registration role must be caregiver or client';
  end if;

  insert into public.profiles (id, full_name, email, phone, role)
  values (
    new.id,
    v_full_name,
    nullif(btrim(new.email), ''),
    case when coalesce(public.has_visible_text(v_phone), false) then v_phone else null end,
    v_role
  );

  return new;
end;
$$;

revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

-- Only clients, administrators and the profile owner can read caregiver rows.
drop policy caregiver_profiles_select_visible on public.caregiver_profiles;
create policy caregiver_profiles_select_visible
on public.caregiver_profiles
for select
to authenticated
using (
  profile_id = (select auth.uid())
  or (select public.is_admin())
  or (
    status = 'approved'
    and exists (
      select 1
      from public.profiles
      where id = (select auth.uid())
        and role = 'client'
    )
  )
);

comment on policy caregiver_profiles_select_visible on public.caregiver_profiles is
  'Owners see their own questionnaire; clients see approved profiles; administrators see all rows.';

commit;
