begin;

-- Profiles are created only by the auth.users trigger after this migration.
-- Removing the client INSERT path prevents bypassing registration validation.
drop policy if exists profiles_insert_own_non_admin on public.profiles;
revoke insert on table public.profiles from authenticated;
revoke insert (id, full_name, email, phone, role)
  on table public.profiles from authenticated;

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
  if v_full_name is null then
    raise exception using
      errcode = '22023',
      message = 'Registration metadata full_name is required';
  end if;

  if v_role is null or v_role not in ('caregiver', 'client') then
    raise exception using
      errcode = '22023',
      message = 'Registration role must be caregiver or client';
  end if;

  insert into public.profiles (
    id,
    full_name,
    email,
    phone,
    role
  ) values (
    new.id,
    v_full_name,
    nullif(btrim(new.email), ''),
    v_phone,
    v_role
  );

  return new;
end;
$$;

revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

-- A single canonical trigger name makes the migration safe against an earlier
-- manually-created version of the same signup hook.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

comment on function public.handle_new_auth_user() is
  'Creates public.profiles atomically after Supabase Auth signup; accepts only caregiver/client metadata roles.';

commit;
