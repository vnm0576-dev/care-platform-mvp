begin;

-- Supabase provides auth.users. pgcrypto supplies gen_random_uuid() on
-- PostgreSQL installations where it is not already available.
create extension if not exists pgcrypto;

create table public.profile_statuses (
  code text primary key,
  title text not null,
  description text,
  visible_to_client boolean not null default false,
  visible_to_caregiver boolean not null default true,
  visible_to_admin boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),

  constraint profile_statuses_code_format_check
    check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint profile_statuses_title_not_blank_check
    check (btrim(title) <> ''),
  constraint profile_statuses_description_not_blank_check
    check (description is null or btrim(description) <> ''),
  constraint profile_statuses_timestamps_check
    check (updated_at >= created_at)
);

comment on table public.profile_statuses is
  'Reference data for caregiver profile moderation statuses.';

create table public.profiles (
  id uuid primary key
    references auth.users (id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  role text not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),

  constraint profiles_id_role_unique unique (id, role),
  constraint profiles_full_name_not_blank_check
    check (btrim(full_name) <> ''),
  constraint profiles_email_not_blank_check
    check (email is null or btrim(email) <> ''),
  constraint profiles_phone_not_blank_check
    check (phone is null or btrim(phone) <> ''),
  constraint profiles_role_check
    check (role in ('caregiver', 'client', 'admin')),
  constraint profiles_timestamps_check
    check (updated_at >= created_at)
);

comment on table public.profiles is
  'Application profile linked one-to-one to Supabase Auth auth.users.';
comment on column public.profiles.id is
  'Same UUID as auth.users.id; this is not a separate application user ID.';

create table public.caregiver_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique,
  profile_role text not null default 'caregiver',
  full_name text,
  city text,
  district text,
  contact_phone text,
  experience text,
  education text,
  certificates text[] not null default '{}'::text[],
  skills text[] not null default '{}'::text[],
  schedule text,
  description text,
  desired_payment numeric(12, 2),
  ready_for_live_in boolean not null default false,
  ready_for_night_shifts boolean not null default false,
  dementia_experience boolean not null default false,
  bedridden_experience boolean not null default false,
  stroke_experience boolean not null default false,
  heart_attack_experience boolean not null default false,
  trauma_experience boolean not null default false,
  photo_url text,
  status text not null default 'draft',
  rejection_reason text,
  hidden_reason text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  submitted_at timestamptz,
  approved_at timestamptz,
  rejected_at timestamptz,
  hidden_at timestamptz,

  constraint caregiver_profiles_owner_role_check
    check (profile_role = 'caregiver'),
  constraint caregiver_profiles_owner_fk
    foreign key (profile_id, profile_role)
    references public.profiles (id, role)
    on update cascade on delete cascade,
  constraint caregiver_profiles_status_fk
    foreign key (status)
    references public.profile_statuses (code)
    on update cascade on delete restrict,
  constraint caregiver_profiles_full_name_not_blank_check
    check (full_name is null or btrim(full_name) <> ''),
  constraint caregiver_profiles_city_not_blank_check
    check (city is null or btrim(city) <> ''),
  constraint caregiver_profiles_district_not_blank_check
    check (district is null or btrim(district) <> ''),
  constraint caregiver_profiles_contact_phone_not_blank_check
    check (contact_phone is null or btrim(contact_phone) <> ''),
  constraint caregiver_profiles_experience_not_blank_check
    check (experience is null or btrim(experience) <> ''),
  constraint caregiver_profiles_education_not_blank_check
    check (education is null or btrim(education) <> ''),
  constraint caregiver_profiles_schedule_not_blank_check
    check (schedule is null or btrim(schedule) <> ''),
  constraint caregiver_profiles_description_not_blank_check
    check (description is null or btrim(description) <> ''),
  constraint caregiver_profiles_photo_url_not_blank_check
    check (photo_url is null or btrim(photo_url) <> ''),
  constraint caregiver_profiles_rejection_reason_not_blank_check
    check (rejection_reason is null or btrim(rejection_reason) <> ''),
  constraint caregiver_profiles_hidden_reason_not_blank_check
    check (hidden_reason is null or btrim(hidden_reason) <> ''),
  constraint caregiver_profiles_desired_payment_check
    check (desired_payment is null or desired_payment >= 0),
  constraint caregiver_profiles_approved_fields_check
    check (
      status <> 'approved'
      or (
        full_name is not null and btrim(full_name) <> ''
        and city is not null and btrim(city) <> ''
        and contact_phone is not null and btrim(contact_phone) <> ''
        and experience is not null and btrim(experience) <> ''
        and schedule is not null and btrim(schedule) <> ''
        and cardinality(skills) > 0
        and description is not null and btrim(description) <> ''
        and approved_at is not null
      )
    ),
  constraint caregiver_profiles_pending_timestamp_check
    check (status <> 'pending_review' or submitted_at is not null),
  constraint caregiver_profiles_rejected_metadata_check
    check (
      status <> 'rejected'
      or (rejection_reason is not null and rejected_at is not null)
    ),
  constraint caregiver_profiles_hidden_metadata_check
    check (
      status <> 'hidden'
      or (hidden_reason is not null and hidden_at is not null)
    ),
  constraint caregiver_profiles_timestamps_check
    check (
      updated_at >= created_at
      and (submitted_at is null or submitted_at >= created_at)
      and (approved_at is null or approved_at >= created_at)
      and (rejected_at is null or rejected_at >= created_at)
      and (hidden_at is null or hidden_at >= created_at)
    )
);

comment on table public.caregiver_profiles is
  'Caregiver questionnaires. One caregiver application per caregiver profile in MVP v1.';
comment on column public.caregiver_profiles.profile_role is
  'Technical discriminator used with a composite FK to guarantee the owner has caregiver role.';

create table public.client_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  profile_role text not null default 'client',
  city text not null,
  district text,
  care_type text not null,
  description text not null,
  contact_phone text not null,
  preferred_schedule text,
  desired_payment numeric(12, 2),
  needs_live_in boolean not null default false,
  needs_night_shifts boolean not null default false,
  dementia_case boolean not null default false,
  bedridden_case boolean not null default false,
  stroke_case boolean not null default false,
  heart_attack_case boolean not null default false,
  trauma_case boolean not null default false,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),

  constraint client_requests_owner_role_check
    check (profile_role = 'client'),
  constraint client_requests_owner_fk
    foreign key (profile_id, profile_role)
    references public.profiles (id, role)
    on update cascade on delete cascade,
  constraint client_requests_city_not_blank_check
    check (btrim(city) <> ''),
  constraint client_requests_district_not_blank_check
    check (district is null or btrim(district) <> ''),
  constraint client_requests_care_type_not_blank_check
    check (btrim(care_type) <> ''),
  constraint client_requests_description_not_blank_check
    check (btrim(description) <> ''),
  constraint client_requests_contact_phone_not_blank_check
    check (btrim(contact_phone) <> ''),
  constraint client_requests_preferred_schedule_not_blank_check
    check (preferred_schedule is null or btrim(preferred_schedule) <> ''),
  constraint client_requests_desired_payment_check
    check (desired_payment is null or desired_payment >= 0),
  constraint client_requests_timestamps_check
    check (updated_at >= created_at)
);

comment on table public.client_requests is
  'Requests created by clients who want help selecting a caregiver.';
comment on column public.client_requests.profile_role is
  'Technical discriminator used with a composite FK to guarantee the owner has client role.';

create table public.moderation_logs (
  id uuid primary key default gen_random_uuid(),
  caregiver_profile_id uuid not null
    references public.caregiver_profiles (id) on delete cascade,
  admin_profile_id uuid not null,
  admin_role text not null default 'admin',
  old_status text not null
    references public.profile_statuses (code) on update cascade on delete restrict,
  new_status text not null
    references public.profile_statuses (code) on update cascade on delete restrict,
  reason text not null,
  comment text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),

  constraint moderation_logs_admin_role_check
    check (admin_role = 'admin'),
  constraint moderation_logs_admin_fk
    foreign key (admin_profile_id, admin_role)
    references public.profiles (id, role)
    on update cascade on delete restrict,
  constraint moderation_logs_status_changed_check
    check (old_status <> new_status),
  constraint moderation_logs_reason_not_blank_check
    check (btrim(reason) <> ''),
  constraint moderation_logs_comment_not_blank_check
    check (comment is null or btrim(comment) <> ''),
  constraint moderation_logs_timestamps_check
    check (updated_at >= created_at)
);

comment on table public.moderation_logs is
  'Audit history of administrator decisions for caregiver profiles.';
comment on column public.moderation_logs.admin_role is
  'Technical discriminator used with a composite FK to guarantee moderator role.';

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.clock_timestamp();
  return new;
end;
$$;

create trigger set_profile_statuses_updated_at
before update on public.profile_statuses
for each row execute function public.set_updated_at();

create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger set_caregiver_profiles_updated_at
before update on public.caregiver_profiles
for each row execute function public.set_updated_at();

create trigger set_client_requests_updated_at
before update on public.client_requests
for each row execute function public.set_updated_at();

create trigger set_moderation_logs_updated_at
before update on public.moderation_logs
for each row execute function public.set_updated_at();

-- Required single-column indexes.
create index idx_caregiver_profiles_status
  on public.caregiver_profiles (status);
create index idx_caregiver_profiles_city
  on public.caregiver_profiles (city);
create index idx_caregiver_profiles_district
  on public.caregiver_profiles (district);
create index idx_caregiver_profiles_approved_at
  on public.caregiver_profiles (approved_at desc);
create index idx_caregiver_profiles_created_at
  on public.caregiver_profiles (created_at desc);

create index idx_client_requests_profile_id
  on public.client_requests (profile_id);
create index idx_client_requests_city
  on public.client_requests (city);
create index idx_client_requests_created_at
  on public.client_requests (created_at desc);

create index idx_moderation_logs_caregiver_profile_id
  on public.moderation_logs (caregiver_profile_id);
create index idx_moderation_logs_admin_profile_id
  on public.moderation_logs (admin_profile_id);
create index idx_moderation_logs_created_at
  on public.moderation_logs (created_at desc);

-- Supports stable keyset pagination:
-- where status = 'approved' and city = :city
--   and (approved_at, id) < (:cursor_approved_at, :cursor_id)
-- order by approved_at desc, id desc
-- limit :page_size;
create index idx_caregiver_profiles_approved_city_page
  on public.caregiver_profiles (city, approved_at desc, id desc)
  where status = 'approved';

commit;
