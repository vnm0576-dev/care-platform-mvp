#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
db_name="care_platform_schema_test_${USER}_$$"
tmp_dir="$(mktemp -d /tmp/care-platform-schema-test.XXXXXX)"

cleanup() {
  sudo -u postgres dropdb --if-exists "$db_name" >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

for command_name in psql createdb dropdb; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing PostgreSQL command: $command_name" >&2
    exit 1
  fi
done

sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname=postgres <<'SQL'
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
end;
$$;
SQL

required_files=(
  "supabase/migrations/20260710160000_initial_schema.sql"
  "supabase/migrations/20260710161000_profile_statuses.sql"
  "supabase/migrations/20260712130000_require_meaningful_caregiver_skills.sql"
  "supabase/migrations/20260712140000_repair_legacy_meaningful_skills.sql"
  "supabase/tests/001_initial_schema_test.sql"
)
for relative_path in "${required_files[@]}"; do
  if [[ ! -f "$repo_root/$relative_path" ]]; then
    echo "Missing required schema file: $relative_path" >&2
    exit 1
  fi
  cp "$repo_root/$relative_path" "$tmp_dir/$(basename "$relative_path")"
done
chmod -R a+rX "$tmp_dir"

sudo -u postgres createdb "$db_name"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" <<'SQL'
create extension if not exists pgcrypto;
create schema auth;
create table auth.users (
  id uuid primary key
);
SQL

sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260710160000_initial_schema.sql"
# Run the seed twice to verify that it is idempotent.
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260710161000_profile_statuses.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260710161000_profile_statuses.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" <<'SQL'
-- This row was valid under the previous cardinality(skills) > 0 check.
-- A deployment migration must remediate it before strengthening that check.
insert into auth.users (id) values ('00000000-0000-0000-0000-000000000005');
insert into public.profiles (id, full_name, role) values
  ('00000000-0000-0000-0000-000000000005', 'Legacy Caregiver', 'caregiver');
insert into public.caregiver_profiles (
  profile_id, full_name, city, contact_phone, experience,
  skills, schedule, description, status, approved_at
) values (
  '00000000-0000-0000-0000-000000000005',
  'Legacy Caregiver', 'Chelyabinsk', '+700****0005', '5 years',
  array['   '], 'day shifts', 'Legacy approved profile',
  'approved', clock_timestamp()
);
SQL
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260712130000_require_meaningful_caregiver_skills.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" <<'SQL'
-- Simulate a database where the already-applied version of migration 20260712130000
-- used btrim(), so a tab-only skill remained approved.
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
insert into auth.users (id) values ('00000000-0000-0000-0000-000000000006');
insert into public.profiles (id, full_name, role) values
  ('00000000-0000-0000-0000-000000000006', 'Legacy Tab Caregiver', 'caregiver');
insert into public.caregiver_profiles (
  profile_id, full_name, city, contact_phone, experience,
  skills, schedule, description, status, approved_at
) values (
  '00000000-0000-0000-0000-000000000006',
  'Legacy Tab Caregiver', 'Chelyabinsk', '+700****0006', '5 years',
  array[E'\t'], 'day shifts', 'Legacy tab-only skill profile',
  'approved', clock_timestamp()
);
SQL
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260712140000_repair_legacy_meaningful_skills.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/001_initial_schema_test.sql"
