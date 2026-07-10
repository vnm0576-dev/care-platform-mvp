# Supabase foundation

This directory contains the executable PostgreSQL foundation for MVP v1.

## Files

- `migrations/001_initial_schema.sql` — tables, constraints, relationships, timestamp triggers and indexes.
- `seed/001_profile_statuses.sql` — idempotent seed for caregiver profile statuses.
- `tests/001_initial_schema_test.sql` — database-level assertions.
- `tests/run_local.sh` — disposable PostgreSQL test runner for Linux development environments.

## Apply order

1. Apply `migrations/001_initial_schema.sql`.
2. Apply `seed/001_profile_statuses.sql`.
3. Add RLS policies in a separate migration/issue before exposing tables to application clients.

The migration expects the Supabase-managed `auth.users` table to exist. It does not create or replace that system table.

## Local verification

The local runner requires PostgreSQL client/server tools and passwordless local access through the `postgres` system account:

```bash
./supabase/tests/run_local.sh
```

The runner creates a disposable database, adds a minimal `auth.users` fixture, applies the migration and seed twice, executes assertions, and removes the database.

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

This foundation intentionally does not include RLS policies or Flutter code. RLS must be implemented and tested in the next security-focused issue.
