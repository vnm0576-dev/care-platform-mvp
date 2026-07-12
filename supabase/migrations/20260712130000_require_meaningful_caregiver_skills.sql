begin;

create or replace function public.has_meaningful_caregiver_skills(p_skills text[])
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select cardinality(p_skills) > 0
    and array_position(p_skills, null) is null
    and not exists (
      select 1
      from unnest(p_skills) as skill
      where btrim(skill) = ''
    );
$$;

alter table public.caregiver_profiles
  drop constraint caregiver_profiles_approved_fields_check;

alter table public.caregiver_profiles
  add constraint caregiver_profiles_approved_fields_check
  check (
    status <> 'approved'
    or (
      full_name is not null and btrim(full_name) <> ''
      and city is not null and btrim(city) <> ''
      and contact_phone is not null and btrim(contact_phone) <> ''
      and experience is not null and btrim(experience) <> ''
      and schedule is not null and btrim(schedule) <> ''
      and public.has_meaningful_caregiver_skills(skills)
      and description is not null and btrim(description) <> ''
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

  if v_profile.full_name is null or btrim(v_profile.full_name) = ''
     or v_profile.city is null or btrim(v_profile.city) = ''
     or v_profile.contact_phone is null or btrim(v_profile.contact_phone) = ''
     or v_profile.experience is null or btrim(v_profile.experience) = ''
     or v_profile.schedule is null or btrim(v_profile.schedule) = ''
     or not public.has_meaningful_caregiver_skills(v_profile.skills)
     or v_profile.description is null or btrim(v_profile.description) = '' then
    raise exception using errcode = '23514', message = 'Required caregiver profile fields are incomplete';
  end if;

  update public.caregiver_profiles
  set status = 'pending_review', submitted_at = clock_timestamp(), rejection_reason = null, rejected_at = null
  where id = p_caregiver_profile_id;
end;
$$;

revoke all on function public.submit_caregiver_profile(uuid) from public;
grant execute on function public.submit_caregiver_profile(uuid) to authenticated;

commit;
