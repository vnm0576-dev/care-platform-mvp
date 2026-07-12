# Supabase foundation

This directory contains the executable PostgreSQL foundation for MVP v1.

## Files

- `migrations/20260710160000_initial_schema.sql` — tables, constraints, relationships, timestamp triggers and indexes.
- `migrations/20260710161000_profile_statuses.sql` — idempotent deployment migration for caregiver profile statuses.
- `migrations/20260710162000_rls_policies.sql` — least-privilege grants, RLS policies and protected status-transition RPC functions.
- `migrations/20260710163000_auth_foundation.sql` — automatic `auth.users` → `public.profiles` registration trigger and role validation.
- `migrations/20260712115500_caregiver_profile_editability.sql` — server-side restriction of owner edits to draft/rejected questionnaires.
- `tests/001_initial_schema_test.sql` — database-level schema assertions.
- `tests/002_rls_policies_test.sql` — role isolation, visibility and moderation assertions.
- `tests/003_auth_foundation_test.sql` — registration linkage, metadata validation and privilege-escalation assertions.
- `tests/run_local.sh` — disposable PostgreSQL schema test runner.
- `tests/run_rls_tests.sh` — disposable PostgreSQL RLS and moderation test runner.
- `tests/run_auth_tests.sh` — disposable PostgreSQL Auth foundation test runner.

## Apply order

1. Apply `migrations/20260710160000_initial_schema.sql`.
2. Apply `migrations/20260710161000_profile_statuses.sql`.
3. Apply `migrations/20260710162000_rls_policies.sql` before exposing tables to application clients.
4. Apply `migrations/20260710163000_auth_foundation.sql` to enable automatic profile creation for new signups.
5. Apply `migrations/20260712115500_caregiver_profile_editability.sql` to enforce the editable lifecycle server-side.

These filenames follow the Supabase CLI timestamp migration contract, so `supabase db push` includes both schema and required status reference rows without a separate seed command.

The migration expects the Supabase-managed `auth.users` table to exist. It does not create or replace that system table.

## Local verification

The local runners require PostgreSQL client/server tools and passwordless local access through the `postgres` system account:

```bash
./supabase/tests/run_local.sh
./supabase/tests/run_rls_tests.sh
./supabase/tests/run_auth_tests.sh
```

Each runner creates a disposable database, adds a minimal Supabase Auth fixture, applies the relevant migrations and seed, executes assertions, and removes the database.

## Auth signup contract

New signups must send the following Supabase `options.data` metadata:

```json
{
  "full_name": "User name",
  "role": "caregiver",
  "phone": "+70000000000"
}
```

- `full_name` is required and must be non-empty;
- `role` is required and accepts only `caregiver` or `client`;
- `phone` is optional; `auth.users.phone` is used as a fallback;
- `admin` can never be selected through signup metadata;
- a protected `auth.users` trigger creates `public.profiles` atomically with the same UUID;
- changing `raw_user_meta_data` later does not change the application role;
- existing auth users are not backfilled automatically because their intended role and full name cannot be safely guessed.

Example Flutter/Supabase call:

```dart
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {
    'full_name': fullName,
    'role': selectedRole, // caregiver or client
    if (phone.isNotEmpty) 'phone': phone,
  },
);
```

## RLS and status transitions

Authenticated application users receive least-privilege table and column grants in addition to row policies. Protected fields such as `role`, `status`, moderation reasons and moderation timestamps cannot be written directly.

The Flutter application should call these Supabase RPC functions:

- `submit_caregiver_profile(p_caregiver_profile_id)` — owner submits a complete `draft` or `rejected` questionnaire as `pending_review`;
- `moderate_caregiver_profile(p_caregiver_profile_id, p_new_status, p_reason, p_comment)` — administrator performs an allowed transition and writes `moderation_logs` atomically.

## Role-safe relationships

The technical columns `profile_role` and `admin_role` participate in composite foreign keys. They prevent:

- a client profile from owning a caregiver questionnaire;
- a caregiver profile from owning a client request;
- a non-admin profile from being recorded as a moderator.

These checks remain effective even before application validation and RLS are implemented.

## Approved caregiver pagination

The partial composite index `idx_caregiver_profiles_approved_city_page` supports stable keyset pagination:

```sql
select *
from public.caregiver_profiles
where status = 'approved'
  and city = :city
  and (approved_at, id) < (:cursor_approved_at, :cursor_id)
order by approved_at desc, id desc
limit :page_size;
```

For the first page, omit the cursor condition. The `id` tie-breaker prevents duplicate or skipped rows when several profiles have the same `approved_at` value.

## Scope boundary

This database layer now includes the initial schema, RLS foundation and automatic Auth-to-profile registration. Flutter UI, hosted Supabase project provisioning, email templates, Storage policies, notifications and multi-role accounts remain outside this scope.
