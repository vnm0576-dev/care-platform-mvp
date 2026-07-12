begin;

-- Repair databases where the already-applied skills migration used btrim(),
-- which does not treat tabs and line breaks as blank content.
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
      where skill !~ '[^[:space:]]'
    );
$$;

-- Existing CHECK constraints use this function for future writes but do not
-- revalidate rows when its definition changes. Remove affected profiles from
-- publication and return them to the owner-correctable rejected state.
update public.caregiver_profiles
set status = 'rejected',
    approved_at = null,
    rejected_at = clock_timestamp(),
    rejection_reason = 'Profile requires at least one meaningful skill before publication'
where status = 'approved'
  and not public.has_meaningful_caregiver_skills(skills);

commit;
