#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
db_name="care_platform_rls_test_${USER}_$$"
tmp_dir="$(mktemp -d /tmp/care-platform-rls-test.XXXXXX)"

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

required_files=(
  "supabase/migrations/001_initial_schema.sql"
  "supabase/migrations/002_rls_policies.sql"
  "supabase/migrations/004_caregiver_profile_editability.sql"
  "supabase/seed/001_profile_statuses.sql"
  "supabase/tests/002_rls_policies_test.sql"
)
for relative_path in "${required_files[@]}"; do
  if [[ ! -f "$repo_root/$relative_path" ]]; then
    echo "Missing required RLS file: $relative_path" >&2
    exit 1
  fi
  cp "$repo_root/$relative_path" "$tmp_dir/$(basename "$relative_path")"
done
chmod -R a+rX "$tmp_dir"

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

sudo -u postgres createdb "$db_name"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" <<'SQL'
create extension if not exists pgcrypto;
create schema auth;
create table auth.users (
  id uuid primary key
);
create function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
SQL

sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/001_initial_schema.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/001_profile_statuses.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/002_rls_policies.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/004_caregiver_profile_editability.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/002_rls_policies_test.sql"
