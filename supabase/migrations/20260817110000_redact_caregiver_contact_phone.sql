begin;

-- Keep the existing projection shape while older clients are upgraded, but never
-- expose a caregiver's real phone through catalog reads. A future assignment
-- workflow can disclose contact data through a separate audited RPC.
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
  null::text as contact_phone,
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
  'Restricted client-facing projection of approved caregiver questionnaires; contact_phone is intentionally redacted pending an audited assignment workflow.';

revoke all on table public.approved_caregiver_profiles
from public, anon, authenticated;
grant select on table public.approved_caregiver_profiles to authenticated;

commit;
