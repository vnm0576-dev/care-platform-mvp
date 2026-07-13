begin;

-- Clients receive only the fields required by caregiver search. The view owner
-- evaluates the approved-row projection, while the caller's JWT still controls
-- whether the projection returns any rows.
create or replace view public.approved_caregiver_profiles
with (security_barrier = true, security_invoker = false)
as
select
  id,
  full_name,
  city,
  experience,
  schedule,
  description,
  contact_phone,
  approved_at
from public.caregiver_profiles
where status = 'approved'
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role in ('client', 'admin')
  );

comment on view public.approved_caregiver_profiles is
  'Restricted client-facing projection of approved caregiver questionnaires.';

revoke all on table public.approved_caregiver_profiles
from public, anon, authenticated;
grant select on table public.approved_caregiver_profiles to authenticated;

-- Raw questionnaire rows remain available only to their owner and to admins.
-- Clients must use approved_caregiver_profiles, which omits owner and moderation
-- metadata.
drop policy caregiver_profiles_select_visible on public.caregiver_profiles;
create policy caregiver_profiles_select_visible
on public.caregiver_profiles
for select
to authenticated
using (
  profile_id = (select auth.uid())
  or (select public.is_admin())
);

comment on policy caregiver_profiles_select_visible on public.caregiver_profiles is
  'Owners see their own questionnaire; administrators see all raw rows; clients use the restricted approved projection.';

-- A dedicated service-side bootstrap prevents a role cascade from colliding
-- with caregiver/client ownership constraints after domain data already exists.
create or replace function public.bootstrap_admin(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profiles where id = p_profile_id
  ) then
    raise exception using
      errcode = '22023',
      message = 'Admin bootstrap profile does not exist';
  end if;

  if exists (
    select 1 from public.caregiver_profiles where profile_id = p_profile_id
  ) or exists (
    select 1 from public.client_requests where profile_id = p_profile_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'Admin bootstrap requires a dedicated account without caregiver or client data';
  end if;

  update public.profiles
  set role = 'admin', updated_at = clock_timestamp()
  where id = p_profile_id;
end;
$$;

revoke all on function public.bootstrap_admin(uuid)
from public, anon, authenticated;
grant execute on function public.bootstrap_admin(uuid) to service_role;

comment on function public.bootstrap_admin(uuid) is
  'Promotes a dedicated unused profile to admin from a trusted service-side context.';

commit;
