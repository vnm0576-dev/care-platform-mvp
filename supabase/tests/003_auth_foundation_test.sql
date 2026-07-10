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

-- The trigger function is not directly executable by application roles.
select tests.assert_true(
  not has_function_privilege('authenticated', 'public.handle_new_auth_user()', 'EXECUTE'),
  'authenticated can execute the auth trigger function directly'
);

-- Valid caregiver registration creates a linked application profile.
insert into auth.users (id, email, phone, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-000000000401',
  'caregiver@example.test',
  null,
  '{"full_name":"  Caregiver Auth  ","role":"caregiver","phone":"  +70000000401  "}'::jsonb
);
select tests.assert_true(
  exists (
    select 1
    from public.profiles
    where id = '00000000-0000-0000-0000-000000000401'
      and full_name = 'Caregiver Auth'
      and email = 'caregiver@example.test'
      and phone = '+70000000401'
      and role = 'caregiver'
  ),
  'caregiver registration did not create the expected linked profile'
);

-- Valid client registration supports auth.users.phone as a fallback.
insert into auth.users (id, email, phone, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-000000000402',
  'client@example.test',
  '  +70000000402  ',
  '{"full_name":"Client Auth","role":"client"}'::jsonb
);
select tests.assert_true(
  exists (
    select 1
    from public.profiles
    where id = '00000000-0000-0000-0000-000000000402'
      and full_name = 'Client Auth'
      and email = 'client@example.test'
      and phone = '+70000000402'
      and role = 'client'
  ),
  'client registration did not create the expected linked profile'
);

-- Metadata is normalized at the boundary but can never produce admin.
insert into auth.users (id, email, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-000000000403',
  'normalized@example.test',
  '{"full_name":"Normalized Role","role":" CareGiver "}'::jsonb
);
select tests.assert_true(
  (select role = 'caregiver'
   from public.profiles
   where id = '00000000-0000-0000-0000-000000000403'),
  'caregiver role normalization failed'
);

-- Invalid registrations are atomic: neither auth.users nor profiles persist.
do $$
begin
  begin
    insert into auth.users (id, email, raw_user_meta_data)
    values (
      '00000000-0000-0000-0000-000000000410',
      'admin-attempt@example.test',
      '{"full_name":"Admin Attempt","role":"admin"}'::jsonb
    );
    raise exception 'admin role registration was accepted';
  exception
    when invalid_parameter_value then null;
  end;
end;
$$;
select tests.assert_true(
  not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-000000000410')
  and not exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-000000000410'),
  'admin registration was not rolled back atomically'
);

do $$
begin
  begin
    insert into auth.users (id, email, raw_user_meta_data)
    values (
      '00000000-0000-0000-0000-000000000411',
      'unknown-role@example.test',
      '{"full_name":"Unknown Role","role":"moderator"}'::jsonb
    );
    raise exception 'unknown role registration was accepted';
  exception
    when invalid_parameter_value then null;
  end;
end;
$$;
select tests.assert_true(
  not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-000000000411'),
  'unknown role auth user survived failed registration'
);

do $$
begin
  begin
    insert into auth.users (id, email, raw_user_meta_data)
    values (
      '00000000-0000-0000-0000-000000000412',
      'missing-role@example.test',
      '{"full_name":"Missing Role"}'::jsonb
    );
    raise exception 'missing role registration was accepted';
  exception
    when invalid_parameter_value then null;
  end;
end;
$$;
select tests.assert_true(
  not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-000000000412'),
  'missing role auth user survived failed registration'
);

do $$
begin
  begin
    insert into auth.users (id, email, raw_user_meta_data)
    values (
      '00000000-0000-0000-0000-000000000413',
      'missing-name@example.test',
      '{"role":"client"}'::jsonb
    );
    raise exception 'missing full_name registration was accepted';
  exception
    when invalid_parameter_value then null;
  end;
end;
$$;
select tests.assert_true(
  not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-000000000413'),
  'missing-name auth user survived failed registration'
);

-- Updating untrusted metadata later does not mutate the application role.
update auth.users
set raw_user_meta_data = '{"full_name":"Caregiver Auth","role":"admin"}'::jsonb
where id = '00000000-0000-0000-0000-000000000401';
select tests.assert_true(
  (select role = 'caregiver'
   from public.profiles
   where id = '00000000-0000-0000-0000-000000000401'),
  'metadata update changed the application role'
);

-- A legacy auth user without profile cannot bypass the trigger flow through a
-- direct authenticated INSERT into public.profiles.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000499', false);
set role authenticated;
do $$
begin
  begin
    insert into public.profiles (id, full_name, role)
    values ('00000000-0000-0000-0000-000000000499', 'Legacy Direct Insert', 'client');
    raise exception 'authenticated direct profile insert was accepted';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;
reset role;
select tests.assert_true(
  not exists (
    select 1 from public.profiles
    where id = '00000000-0000-0000-0000-000000000499'
  ),
  'direct profile insert created a row'
);

-- Existing FK cascade keeps auth.users and public.profiles lifecycle aligned.
delete from auth.users
where id = '00000000-0000-0000-0000-000000000402';
select tests.assert_true(
  not exists (
    select 1 from public.profiles
    where id = '00000000-0000-0000-0000-000000000402'
  ),
  'deleting auth.users did not cascade to public.profiles'
);

select 'Supabase Auth foundation tests passed' as result;
