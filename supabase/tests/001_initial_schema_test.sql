\set ON_ERROR_STOP on

-- Executed after the initial schema and profile status production migrations.
-- The auth.users table is created by the local test fixture.

create schema if not exists tests;

create or replace function tests.assert_true(condition boolean, message text)
returns void
language plpgsql
as $$
begin
  if condition is not true then
    raise exception 'Assertion failed: %', message;
  end if;
end;
$$;

-- Required MVP tables exist.
select tests.assert_true(to_regclass('public.profiles') is not null, 'profiles table is missing');
select tests.assert_true(to_regclass('public.caregiver_profiles') is not null, 'caregiver_profiles table is missing');
select tests.assert_true(to_regclass('public.client_requests') is not null, 'client_requests table is missing');
select tests.assert_true(to_regclass('public.profile_statuses') is not null, 'profile_statuses table is missing');
select tests.assert_true(to_regclass('public.moderation_logs') is not null, 'moderation_logs table is missing');

-- profiles.id must reference Supabase Auth.
select tests.assert_true(
  exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join pg_class rt on rt.oid = c.confrelid
    join pg_namespace rn on rn.oid = rt.relnamespace
    where c.contype = 'f'
      and n.nspname = 'public'
      and t.relname = 'profiles'
      and rn.nspname = 'auth'
      and rt.relname = 'users'
  ),
  'profiles must reference auth.users'
);

-- Seed contains exactly the documented status codes.
select tests.assert_true(
  (select array_agg(code order by code) from public.profile_statuses)
    = array['approved', 'draft', 'hidden', 'pending_review', 'rejected']::text[],
  'profile status seed is incomplete or contains unexpected codes'
);
select tests.assert_true(
  (select visible_to_client from public.profile_statuses where code = 'approved'),
  'approved must be visible to clients'
);
select tests.assert_true(
  not (select visible_to_client from public.profile_statuses where code = 'pending_review'),
  'pending_review must not be visible to clients'
);

-- Unsupported roles are rejected.
insert into auth.users (id) values ('00000000-0000-0000-0000-000000000001');
do $$
begin
  begin
    insert into public.profiles (id, full_name, role)
    values ('00000000-0000-0000-0000-000000000001', 'Invalid role', 'outsider');
    raise exception 'unsupported profile role was accepted';
  exception
    when check_violation then null;
  end;
end;
$$;

-- Role-specific relationships are enforced at database level.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000003'),
  ('00000000-0000-0000-0000-000000000004');
insert into public.profiles (id, full_name, role) values
  ('00000000-0000-0000-0000-000000000002', 'Caregiver', 'caregiver'),
  ('00000000-0000-0000-0000-000000000003', 'Client', 'client'),
  ('00000000-0000-0000-0000-000000000004', 'Admin', 'admin');

do $$
begin
  begin
    insert into public.caregiver_profiles (profile_id)
    values ('00000000-0000-0000-0000-000000000003');
    raise exception 'client profile was accepted as caregiver';
  exception
    when foreign_key_violation then null;
  end;
end;
$$;

do $$
begin
  begin
    insert into public.client_requests (profile_id, city, care_type, description, contact_phone)
    values (
      '00000000-0000-0000-0000-000000000002',
      'Chelyabinsk', 'home_care', 'Test request', '+70000000000'
    );
    raise exception 'caregiver profile was accepted as client';
  exception
    when foreign_key_violation then null;
  end;
end;
$$;

-- An approved caregiver profile must contain publication fields.
do $$
begin
  begin
    insert into public.caregiver_profiles (profile_id, status, approved_at)
    values (
      '00000000-0000-0000-0000-000000000002',
      'approved',
      clock_timestamp()
    );
    raise exception 'incomplete caregiver profile was approved';
  exception
    when check_violation then null;
  end;
end;
$$;

insert into public.caregiver_profiles (
  profile_id, full_name, city, contact_phone, experience,
  skills, schedule, description, status, approved_at
) values (
  '00000000-0000-0000-0000-000000000002',
  'Test Caregiver', 'Chelyabinsk', '+70000000001', '5 years',
  array['hygiene care'], 'day shifts', 'Test approved profile',
  'approved', clock_timestamp()
);

-- updated_at is maintained automatically.
do $$
declare
  before_value timestamptz;
  after_value timestamptz;
begin
  select updated_at into before_value
  from public.caregiver_profiles
  where profile_id = '00000000-0000-0000-0000-000000000002';

  perform pg_sleep(0.01);
  update public.caregiver_profiles
  set description = 'Updated description'
  where profile_id = '00000000-0000-0000-0000-000000000002';

  select updated_at into after_value
  from public.caregiver_profiles
  where profile_id = '00000000-0000-0000-0000-000000000002';

  perform tests.assert_true(after_value > before_value, 'updated_at trigger did not advance timestamp');
end;
$$;

-- A non-admin profile cannot be recorded as moderator.
do $$
begin
  begin
    insert into public.moderation_logs (
      caregiver_profile_id, admin_profile_id, old_status, new_status, reason
    )
    select id,
      '00000000-0000-0000-0000-000000000003',
      'pending_review', 'approved', 'Invalid moderator'
    from public.caregiver_profiles
    where profile_id = '00000000-0000-0000-0000-000000000002';
    raise exception 'non-admin profile was accepted as moderator';
  exception
    when foreign_key_violation then null;
  end;
end;
$$;

-- Required indexes and the keyset-pagination index exist.
select tests.assert_true(to_regclass('public.idx_caregiver_profiles_status') is not null, 'status index is missing');
select tests.assert_true(to_regclass('public.idx_caregiver_profiles_city') is not null, 'city index is missing');
select tests.assert_true(to_regclass('public.idx_caregiver_profiles_district') is not null, 'district index is missing');
select tests.assert_true(to_regclass('public.idx_caregiver_profiles_approved_at') is not null, 'approved_at index is missing');
select tests.assert_true(to_regclass('public.idx_caregiver_profiles_created_at') is not null, 'caregiver created_at index is missing');
select tests.assert_true(to_regclass('public.idx_caregiver_profiles_approved_city_page') is not null, 'approved caregiver pagination index is missing');
select tests.assert_true(to_regclass('public.idx_client_requests_profile_id') is not null, 'client request profile index is missing');
select tests.assert_true(to_regclass('public.idx_client_requests_city') is not null, 'client request city index is missing');
select tests.assert_true(to_regclass('public.idx_client_requests_created_at') is not null, 'client request created_at index is missing');
select tests.assert_true(to_regclass('public.idx_moderation_logs_caregiver_profile_id') is not null, 'moderation caregiver index is missing');
select tests.assert_true(to_regclass('public.idx_moderation_logs_admin_profile_id') is not null, 'moderation admin index is missing');
select tests.assert_true(to_regclass('public.idx_moderation_logs_created_at') is not null, 'moderation created_at index is missing');

select 'Supabase foundation schema tests passed' as result;
