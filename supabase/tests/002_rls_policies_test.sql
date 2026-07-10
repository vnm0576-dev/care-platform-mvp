\set ON_ERROR_STOP on

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
grant usage on schema tests to authenticated;
grant execute on function tests.assert_true(boolean, text) to authenticated;

-- Fixed auth and application fixtures.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000101'),
  ('00000000-0000-0000-0000-000000000102'),
  ('00000000-0000-0000-0000-000000000103'),
  ('00000000-0000-0000-0000-000000000104'),
  ('00000000-0000-0000-0000-000000000105'),
  ('00000000-0000-0000-0000-000000000106');

insert into public.profiles (id, full_name, role) values
  ('00000000-0000-0000-0000-000000000101', 'Caregiver One', 'caregiver'),
  ('00000000-0000-0000-0000-000000000102', 'Caregiver Two', 'caregiver'),
  ('00000000-0000-0000-0000-000000000103', 'Client One', 'client'),
  ('00000000-0000-0000-0000-000000000104', 'Client Two', 'client'),
  ('00000000-0000-0000-0000-000000000105', 'Administrator', 'admin');

insert into public.caregiver_profiles (
  id, profile_id, full_name, city, contact_phone, experience,
  skills, schedule, description, status, created_at, updated_at, approved_at
) values
  (
    '10000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000101',
    'Caregiver One', 'Chelyabinsk', '+700****0001', '5 years',
    array['hygiene care'], 'day shifts', 'Approved caregiver',
    'approved', statement_timestamp(), statement_timestamp(), statement_timestamp()
  ),
  (
    '10000000-0000-0000-0000-000000000202',
    '00000000-0000-0000-0000-000000000102',
    'Caregiver Two', 'Chelyabinsk', '+700****0002', '3 years',
    array['mobility assistance'], 'night shifts', 'Draft caregiver',
    'draft', statement_timestamp(), statement_timestamp(), null
  );

insert into public.client_requests (
  id, profile_id, city, care_type, description, contact_phone
) values
  (
    '20000000-0000-0000-0000-000000000301',
    '00000000-0000-0000-0000-000000000103',
    'Chelyabinsk', 'dementia_care', 'Request one', '+70000000003'
  ),
  (
    '20000000-0000-0000-0000-000000000302',
    '00000000-0000-0000-0000-000000000104',
    'Chelyabinsk', 'post_stroke_care', 'Request two', '+70000000004'
  );

-- RLS is enabled on all exposed tables.
select tests.assert_true(
  (select count(*) = 5
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in ('profiles', 'caregiver_profiles', 'client_requests', 'profile_statuses', 'moderation_logs')
     and c.relrowsecurity),
  'RLS must be enabled on all five MVP tables'
);

-- A new user cannot self-assign admin but can create a normal own profile.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000106', false);
set role authenticated;
do $$
begin
  begin
    insert into public.profiles (id, full_name, role)
    values ('00000000-0000-0000-0000-000000000106', 'Self Admin', 'admin');
    raise exception 'self-assigned admin role was accepted';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;
insert into public.profiles (id, full_name, role)
values ('00000000-0000-0000-0000-000000000106', 'Client Three', 'client');
select tests.assert_true(
  (select count(*) from public.profiles) = 1,
  'ordinary user must see only their own profile'
);
do $$
begin
  begin
    update public.profiles
    set role = 'admin'
    where id = '00000000-0000-0000-0000-000000000106';
    raise exception 'direct profile role update was accepted';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Client sees approved caregiver profiles only.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000103', false);
set role authenticated;
select tests.assert_true(
  (select count(*) from public.caregiver_profiles) = 1,
  'client must see only approved caregiver profiles'
);
select tests.assert_true(
  not exists (select 1 from public.caregiver_profiles where status <> 'approved'),
  'client saw a non-approved caregiver profile'
);
select tests.assert_true(
  (select count(*) from public.client_requests) = 1,
  'client must see only their own request'
);
reset role;

-- Caregiver sees their own application and public approved applications,
-- but cannot see client requests.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', false);
set role authenticated;
select tests.assert_true(
  exists (
    select 1 from public.caregiver_profiles
    where id = '10000000-0000-0000-0000-000000000202'
  ),
  'caregiver cannot see their own draft'
);
select tests.assert_true(
  (select count(*) from public.client_requests) = 0,
  'caregiver saw client requests'
);
do $$
begin
  begin
    update public.caregiver_profiles
    set status = 'approved'
    where id = '10000000-0000-0000-0000-000000000202';
    raise exception 'direct caregiver status update was accepted';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Another user cannot submit the caregiver's application.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000103', false);
set role authenticated;
do $$
begin
  begin
    perform public.submit_caregiver_profile('10000000-0000-0000-0000-000000000202');
    raise exception 'another user submitted a foreign caregiver profile';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Owner can submit a complete draft.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', false);
set role authenticated;
select public.submit_caregiver_profile('10000000-0000-0000-0000-000000000202');
select tests.assert_true(
  exists (
    select 1 from public.caregiver_profiles
    where id = '10000000-0000-0000-0000-000000000202'
      and status = 'pending_review'
      and submitted_at is not null
  ),
  'owner submission did not set pending_review and submitted_at'
);

-- Ordinary user cannot moderate or write the audit log directly.
do $$
begin
  begin
    perform public.moderate_caregiver_profile(
      '10000000-0000-0000-0000-000000000202',
      'approved', 'Unauthorized moderation', null
    );
    raise exception 'ordinary user moderated caregiver profile';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;
do $$
begin
  begin
    insert into public.moderation_logs (
      caregiver_profile_id, admin_profile_id, old_status, new_status, reason
    ) values (
      '10000000-0000-0000-0000-000000000202',
      '00000000-0000-0000-0000-000000000105',
      'pending_review', 'approved', 'Direct write'
    );
    raise exception 'ordinary user wrote moderation log directly';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;
select tests.assert_true(
  (select count(*) from public.moderation_logs) = 0,
  'ordinary user can read moderation logs'
);
reset role;

-- Admin sees all protected data and moderates atomically.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000105', false);
set role authenticated;
select tests.assert_true(
  (select count(*) from public.profiles) = 6,
  'admin must see all profiles'
);
select tests.assert_true(
  (select count(*) from public.caregiver_profiles) = 2,
  'admin must see all caregiver profiles'
);
select tests.assert_true(
  (select count(*) from public.client_requests) = 2,
  'admin must see all client requests'
);
select public.moderate_caregiver_profile(
  '10000000-0000-0000-0000-000000000202',
  'approved', 'Questionnaire verified', 'Approved in RLS test'
);
select tests.assert_true(
  exists (
    select 1 from public.caregiver_profiles
    where id = '10000000-0000-0000-0000-000000000202'
      and status = 'approved'
      and approved_at is not null
  ),
  'admin moderation did not approve caregiver profile'
);
select tests.assert_true(
  exists (
    select 1 from public.moderation_logs
    where caregiver_profile_id = '10000000-0000-0000-0000-000000000202'
      and admin_profile_id = '00000000-0000-0000-0000-000000000105'
      and old_status = 'pending_review'
      and new_status = 'approved'
  ),
  'admin moderation did not create audit log'
);
reset role;

-- Client now sees both approved profiles, while audit log stays hidden.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000103', false);
set role authenticated;
select tests.assert_true(
  (select count(*) from public.caregiver_profiles) = 2,
  'newly approved caregiver is not visible to client'
);
select tests.assert_true(
  (select count(*) from public.moderation_logs) = 0,
  'client can read moderation logs'
);
reset role;

select 'Supabase RLS and moderation tests passed' as result;
