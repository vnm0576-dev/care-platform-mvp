# Supabase foundation

This directory contains the executable PostgreSQL foundation for MVP v1.

## Files

- `migrations/001_initial_schema.sql` — tables, constraints, relationships, timestamp triggers and indexes.
- `migrations/002_rls_policies.sql` — least-privilege grants, RLS policies and protected status-transition RPC functions.
- `seed/001_profile_statuses.sql` — idempotent seed for caregiver profile statuses.
- `tests/001_initial_schema_test.sql` — database-level schema assertions.
- `tests/002_rls_policies_test.sql` — role isolation, visibility and moderation assertions.
- `tests/run_local.sh` — disposable PostgreSQL schema test runner.
- `tests/run_rls_tests.sh` — disposable PostgreSQL RLS and moderation test runner.

## Apply order

1. Apply `migrations/001_initial_schema.sql`.
2. Apply `seed/001_profile_statuses.sql`.
3. Apply `migrations/002_rls_policies.sql` before exposing tables to application clients.

The migration expects the Supabase-managed `auth.users` table to exist. It does not create or replace that system table.

## Local verification

The local runners require PostgreSQL client/server tools and passwordless local access through the `postgres` system account:

```bash
./supabase/tests/run_local.sh
./supabase/tests/run_rls_tests.sh
```

Each runner creates a disposable database, adds a minimal Supabase Auth fixture, applies the relevant migrations and seed, executes assertions, and removes the database.

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

This database layer now includes the initial schema and RLS foundation. Flutter UI, Supabase Storage policies, notifications and multi-role accounts remain outside this scope.
