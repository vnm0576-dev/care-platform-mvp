begin;

-- Helper used by RLS policies. SECURITY DEFINER avoids recursive RLS checks on
-- public.profiles while still deriving identity from the Supabase JWT.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  )
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.caregiver_profiles enable row level security;
alter table public.client_requests enable row level security;
alter table public.profile_statuses enable row level security;
alter table public.moderation_logs enable row level security;

-- Remove broad Supabase grants before adding least-privilege table and column
-- grants. The service_role and database owner retain their administrative path.
revoke all privileges on table public.profiles from anon, authenticated;
revoke all privileges on table public.caregiver_profiles from anon, authenticated;
revoke all privileges on table public.client_requests from anon, authenticated;
revoke all privileges on table public.profile_statuses from anon, authenticated;
revoke all privileges on table public.moderation_logs from anon, authenticated;

-- profiles
create policy profiles_select_own_or_admin
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or (select public.is_admin())
);

create policy profiles_insert_own_non_admin
on public.profiles
for insert
to authenticated
with check (
  id = (select auth.uid())
  and role in ('caregiver', 'client')
);

create policy profiles_update_own_or_admin
on public.profiles
for update
to authenticated
using (
  id = (select auth.uid())
  or (select public.is_admin())
)
with check (
  id = (select auth.uid())
  or (select public.is_admin())
);

grant select on table public.profiles to authenticated;
grant insert (id, full_name, email, phone, role)
  on table public.profiles to authenticated;
grant update (full_name, email, phone)
  on table public.profiles to authenticated;

-- caregiver_profiles
create policy caregiver_profiles_select_visible
on public.caregiver_profiles
for select
to authenticated
using (
  profile_id = (select auth.uid())
  or status = 'approved'
  or (select public.is_admin())
);

create policy caregiver_profiles_insert_own_draft
on public.caregiver_profiles
for insert
to authenticated
with check (
  profile_id = (select auth.uid())
  and profile_role = 'caregiver'
  and status = 'draft'
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'caregiver'
  )
);

create policy caregiver_profiles_update_own
on public.caregiver_profiles
for update
to authenticated
using (profile_id = (select auth.uid()))
with check (
  profile_id = (select auth.uid())
  and profile_role = 'caregiver'
);

grant select on table public.caregiver_profiles to authenticated;
grant insert (
  profile_id,
  full_name,
  city,
  district,
  contact_phone,
  experience,
  education,
  certificates,
  skills,
  schedule,
  description,
  desired_payment,
  ready_for_live_in,
  ready_for_night_shifts,
  dementia_experience,
  bedridden_experience,
  stroke_experience,
  heart_attack_experience,
  trauma_experience,
  photo_url
) on table public.caregiver_profiles to authenticated;
grant update (
  full_name,
  city,
  district,
  contact_phone,
  experience,
  education,
  certificates,
  skills,
  schedule,
  description,
  desired_payment,
  ready_for_live_in,
  ready_for_night_shifts,
  dementia_experience,
  bedridden_experience,
  stroke_experience,
  heart_attack_experience,
  trauma_experience,
  photo_url
) on table public.caregiver_profiles to authenticated;

-- client_requests
create policy client_requests_select_own_or_admin
on public.client_requests
for select
to authenticated
using (
  profile_id = (select auth.uid())
  or (select public.is_admin())
);

create policy client_requests_insert_own
on public.client_requests
for insert
to authenticated
with check (
  profile_id = (select auth.uid())
  and profile_role = 'client'
  and exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'client'
  )
);

create policy client_requests_update_own
on public.client_requests
for update
to authenticated
using (profile_id = (select auth.uid()))
with check (
  profile_id = (select auth.uid())
  and profile_role = 'client'
);

create policy client_requests_delete_own
on public.client_requests
for delete
to authenticated
using (profile_id = (select auth.uid()));

grant select on table public.client_requests to authenticated;
grant insert (
  profile_id,
  city,
  district,
  care_type,
  description,
  contact_phone,
  preferred_schedule,
  desired_payment,
  needs_live_in,
  needs_night_shifts,
  dementia_case,
  bedridden_case,
  stroke_case,
  heart_attack_case,
  trauma_case
) on table public.client_requests to authenticated;
grant update (
  city,
  district,
  care_type,
  description,
  contact_phone,
  preferred_schedule,
  desired_payment,
  needs_live_in,
  needs_night_shifts,
  dementia_case,
  bedridden_case,
  stroke_case,
  heart_attack_case,
  trauma_case
) on table public.client_requests to authenticated;
grant delete on table public.client_requests to authenticated;

-- Status reference data is readable after login but not writable through the
-- application roles.
create policy profile_statuses_select_authenticated
on public.profile_statuses
for select
to authenticated
using (true);

grant select on table public.profile_statuses to authenticated;

-- moderation_logs are admin-readable and function-written only.
create policy moderation_logs_select_admin
on public.moderation_logs
for select
to authenticated
using ((select public.is_admin()));

grant select on table public.moderation_logs to authenticated;

-- A caregiver uses this RPC instead of directly updating status. Required
-- publication fields are checked before the questionnaire enters moderation.
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
    raise exception using
      errcode = '42501',
      message = 'Authentication is required';
  end if;

  select *
  into v_profile
  from public.caregiver_profiles
  where id = p_caregiver_profile_id
  for update;

  if not found or v_profile.profile_id <> v_user_id then
    raise exception using
      errcode = '42501',
      message = 'Caregiver profile does not belong to the current user';
  end if;

  if v_profile.status not in ('draft', 'rejected') then
    raise exception using
      errcode = '22023',
      message = 'Only draft or rejected profiles can be submitted';
  end if;

  if v_profile.full_name is null or btrim(v_profile.full_name) = ''
     or v_profile.city is null or btrim(v_profile.city) = ''
     or v_profile.contact_phone is null or btrim(v_profile.contact_phone) = ''
     or v_profile.experience is null or btrim(v_profile.experience) = ''
     or v_profile.schedule is null or btrim(v_profile.schedule) = ''
     or cardinality(v_profile.skills) = 0
     or v_profile.description is null or btrim(v_profile.description) = '' then
    raise exception using
      errcode = '23514',
      message = 'Required caregiver profile fields are incomplete';
  end if;

  update public.caregiver_profiles
  set
    status = 'pending_review',
    submitted_at = clock_timestamp(),
    rejection_reason = null,
    rejected_at = null
  where id = p_caregiver_profile_id;
end;
$$;

revoke all on function public.submit_caregiver_profile(uuid) from public;
grant execute on function public.submit_caregiver_profile(uuid) to authenticated;

-- An admin uses this RPC to update the questionnaire and append an audit row
-- within the same database transaction.
create or replace function public.moderate_caregiver_profile(
  p_caregiver_profile_id uuid,
  p_new_status text,
  p_reason text,
  p_comment text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_status text;
  v_admin_id uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
begin
  if v_admin_id is null or not public.is_admin() then
    raise exception using
      errcode = '42501',
      message = 'Administrator role is required';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using
      errcode = '22023',
      message = 'Moderation reason is required';
  end if;

  select status
  into v_old_status
  from public.caregiver_profiles
  where id = p_caregiver_profile_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Caregiver profile not found';
  end if;

  if not (
    (v_old_status = 'pending_review' and p_new_status in ('approved', 'rejected'))
    or (v_old_status = 'approved' and p_new_status = 'hidden')
    or (v_old_status = 'hidden' and p_new_status = 'approved')
  ) then
    raise exception using
      errcode = '22023',
      message = format('Invalid moderation transition: %s -> %s', v_old_status, p_new_status);
  end if;

  update public.caregiver_profiles
  set
    status = p_new_status,
    approved_at = case
      when p_new_status = 'approved' then v_now
      else approved_at
    end,
    rejection_reason = case
      when p_new_status = 'rejected' then p_reason
      when p_new_status = 'approved' then null
      else rejection_reason
    end,
    rejected_at = case
      when p_new_status = 'rejected' then v_now
      when p_new_status = 'approved' then null
      else rejected_at
    end,
    hidden_reason = case
      when p_new_status = 'hidden' then p_reason
      when p_new_status = 'approved' then null
      else hidden_reason
    end,
    hidden_at = case
      when p_new_status = 'hidden' then v_now
      when p_new_status = 'approved' then null
      else hidden_at
    end
  where id = p_caregiver_profile_id;

  insert into public.moderation_logs (
    caregiver_profile_id,
    admin_profile_id,
    old_status,
    new_status,
    reason,
    comment
  ) values (
    p_caregiver_profile_id,
    v_admin_id,
    v_old_status,
    p_new_status,
    btrim(p_reason),
    nullif(btrim(p_comment), '')
  );
end;
$$;

revoke all on function public.moderate_caregiver_profile(uuid, text, text, text) from public;
grant execute on function public.moderate_caregiver_profile(uuid, text, text, text)
  to authenticated;

comment on function public.submit_caregiver_profile(uuid) is
  'Owner-only transition from draft/rejected to pending_review after completeness checks.';
comment on function public.moderate_caregiver_profile(uuid, text, text, text) is
  'Admin-only moderation transition with an atomic moderation_logs insert.';

commit;
