begin;

-- Client UI state can become stale while an administrator changes the profile
-- lifecycle. Enforce editability on the current database row as well.
drop policy if exists caregiver_profiles_update_own
on public.caregiver_profiles;

create policy caregiver_profiles_update_own_editable
on public.caregiver_profiles
for update
to authenticated
using (
  profile_id = (select auth.uid())
  and profile_role = 'caregiver'
  and status in ('draft', 'rejected')
)
with check (
  profile_id = (select auth.uid())
  and profile_role = 'caregiver'
  and status in ('draft', 'rejected')
);

comment on policy caregiver_profiles_update_own_editable
on public.caregiver_profiles is
  'Owners may edit permitted content only while their questionnaire is draft or rejected; status transitions use protected RPCs.';

commit;
