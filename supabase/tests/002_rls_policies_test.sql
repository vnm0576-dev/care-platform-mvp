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

-- The hardening migration must preserve valid moderation metadata while
-- replacing whitespace-only legacy values and clearing stale approval data.
select tests.assert_true(
  exists (
    select 1 from public.caregiver_profiles
    where profile_id = '00000000-0000-0000-0000-000000000008'
      and status = 'rejected'
      and public.has_visible_text(rejection_reason)
      and rejected_at is not null
  ),
  'legacy rejected profile lost required moderation metadata during sanitization'
);
select tests.assert_true(
  exists (
    select 1 from public.caregiver_profiles
    where profile_id = '00000000-0000-0000-0000-000000000009'
      and status = 'hidden'
      and public.has_visible_text(hidden_reason)
      and hidden_at is not null
  ),
  'legacy hidden profile lost required moderation metadata during sanitization'
);
select tests.assert_true(
  exists (
    select 1 from public.caregiver_profiles
    where profile_id = '00000000-0000-0000-0000-000000000010'
      and status = 'rejected'
      and approved_at is null
      and public.has_visible_text(rejection_reason)
  ),
  'invalid approved profile retained stale approval metadata after demotion'
);
select tests.assert_true(
  has_function_privilege('service_role', 'public.has_visible_text(text)', 'EXECUTE'),
  'service_role cannot execute the text validator used by table constraints'
);

-- Fixed auth and application fixtures.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000101', 'caregiver1@example.test', '{"full_name":"Caregiver One","role":"caregiver"}'),
  ('00000000-0000-0000-0000-000000000102', 'caregiver2@example.test', '{"full_name":"Caregiver Two","role":"caregiver"}'),
  ('00000000-0000-0000-0000-000000000103', 'client1@example.test', '{"full_name":"Client One","role":"client"}'),
  ('00000000-0000-0000-0000-000000000104', 'client2@example.test', '{"full_name":"Client Two","role":"client"}'),
  ('00000000-0000-0000-0000-000000000105', 'admin@example.test', '{"full_name":"Administrator","role":"client"}'),
  ('00000000-0000-0000-0000-000000000106', 'client3@example.test', '{"full_name":"Client Three","role":"client"}');

update public.profiles
set role = 'admin'
where id = '00000000-0000-0000-0000-000000000105';

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

-- Profiles are trigger-created; authenticated users cannot insert or self-assign admin.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000106', false);
set role authenticated;
select tests.assert_true(
  not has_table_privilege('authenticated', 'public.profiles', 'INSERT'),
  'authenticated retained INSERT privilege on profiles'
);
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
  (select count(*) from public.caregiver_profiles) = 1,
  'caregiver can read another caregiver profile or contact data'
);
update public.caregiver_profiles
set description = 'Edited eligible draft'
where id = '10000000-0000-0000-0000-000000000202';
select tests.assert_true(
  (select description from public.caregiver_profiles
   where id = '10000000-0000-0000-0000-000000000202') = 'Edited eligible draft',
  'caregiver cannot edit their own draft'
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

-- The owner may edit an eligible draft, but a stale client must not be able to
-- mutate permitted content after an external status transition.
reset role;
update public.caregiver_profiles
set
  status = 'rejected',
  rejection_reason = 'Needs clarification',
  rejected_at = statement_timestamp()
where id = '10000000-0000-0000-0000-000000000202';
set role authenticated;
update public.caregiver_profiles
set description = 'Edited eligible rejected profile'
where id = '10000000-0000-0000-0000-000000000202';
select tests.assert_true(
  (select description from public.caregiver_profiles
   where id = '10000000-0000-0000-0000-000000000202') = 'Edited eligible rejected profile',
  'caregiver cannot edit their own rejected profile'
);
reset role;
update public.caregiver_profiles
set
  status = 'approved',
  rejection_reason = null,
  rejected_at = null,
  approved_at = statement_timestamp()
where id = '10000000-0000-0000-0000-000000000202';
set role authenticated;
do $$
declare
  v_updated integer;
begin
  update public.caregiver_profiles
  set description = 'Stale client changed approved profile'
  where id = '10000000-0000-0000-0000-000000000202';
  get diagnostics v_updated = row_count;
  if v_updated <> 0 then
    raise exception 'owner updated approved caregiver profile';
  end if;
end;
$$;
reset role;
update public.caregiver_profiles
set
  status = 'hidden',
  hidden_reason = 'Moderation hold',
  hidden_at = statement_timestamp()
where id = '10000000-0000-0000-0000-000000000202';
set role authenticated;
do $$
declare
  v_updated integer;
begin
  update public.caregiver_profiles
  set description = 'Stale client changed hidden profile'
  where id = '10000000-0000-0000-0000-000000000202';
  get diagnostics v_updated = row_count;
  if v_updated <> 0 then
    raise exception 'owner updated hidden caregiver profile';
  end if;
end;
$$;
reset role;
update public.caregiver_profiles
set
  status = 'pending_review',
  hidden_reason = null,
  hidden_at = null
where id = '10000000-0000-0000-0000-000000000202';
set role authenticated;
do $$
declare
  v_updated integer;
begin
  update public.caregiver_profiles
  set description = 'Stale client changed pending profile'
  where id = '10000000-0000-0000-0000-000000000202';
  get diagnostics v_updated = row_count;
  if v_updated <> 0 then
    raise exception 'owner updated pending caregiver profile';
  end if;
end;
$$;
select tests.assert_true(
  (select description from public.caregiver_profiles
   where id = '10000000-0000-0000-0000-000000000202') = 'Edited eligible rejected profile',
  'stale client changed caregiver profile content'
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
  (select count(*) from public.profiles) = 9,
  'admin must see all profiles'
);
select tests.assert_true(
  (select count(*) from public.caregiver_profiles) = 5,
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
