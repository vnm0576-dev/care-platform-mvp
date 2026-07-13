begin;

-- The earlier remediation covered only published rows. Hidden legacy profiles
-- can contain whitespace-only skills too; after the stricter rule they cannot
-- be restored and their owner cannot edit them. Return every invalid hidden
-- profile to the owner-editable rejected state.
update public.caregiver_profiles
set status = 'rejected',
    approved_at = null,
    hidden_at = null,
    hidden_reason = null,
    rejected_at = clock_timestamp(),
    rejection_reason = 'Profile requires at least one meaningful skill before publication'
where status = 'hidden'
  and not public.has_meaningful_caregiver_skills(skills);

commit;
