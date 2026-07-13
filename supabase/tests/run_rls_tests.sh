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
  "supabase/migrations/20260710160000_initial_schema.sql"
  "supabase/migrations/20260710161000_profile_statuses.sql"
  "supabase/migrations/20260710162000_rls_policies.sql"
  "supabase/migrations/20260710163000_auth_foundation.sql"
  "supabase/migrations/20260712115500_caregiver_profile_editability.sql"
  "supabase/migrations/20260712130000_require_meaningful_caregiver_skills.sql"
  "supabase/migrations/20260712140000_repair_legacy_meaningful_skills.sql"
  "supabase/migrations/20260712150000_repair_hidden_meaningful_skills.sql"
  "supabase/migrations/20260713100000_harden_profile_text_and_visibility.sql"
  "supabase/migrations/20260713110000_restrict_caregiver_projection_and_admin_bootstrap.sql"
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
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end;
$$;
SQL

sudo -u postgres createdb "$db_name"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" <<'SQL'
create extension if not exists pgcrypto;
create schema auth;
create table auth.users (
  id uuid primary key,
  email text,
  phone text,
  raw_user_meta_data jsonb not null default '{}'::jsonb
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
  --file="$tmp_dir/20260710160000_initial_schema.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260710161000_profile_statuses.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260710162000_rls_policies.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260710163000_auth_foundation.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260712115500_caregiver_profile_editability.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260712130000_require_meaningful_caregiver_skills.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260712140000_repair_legacy_meaningful_skills.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260712150000_repair_hidden_meaningful_skills.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" <<'SQL'
-- Legacy btrim() checks accepted tab/newline-only moderation reasons and required
-- publication fields. The hardening migration must sanitize them atomically.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000008', 'legacy8@example.test', '{"full_name":"Legacy Rejected Caregiver","role":"caregiver"}'),
  ('00000000-0000-0000-0000-000000000009', 'legacy9@example.test', '{"full_name":"Legacy Hidden Caregiver","role":"caregiver"}'),
  ('00000000-0000-0000-0000-000000000010', 'legacy10@example.test', '{"full_name":"Legacy Approved Caregiver","role":"caregiver"}');
insert into public.caregiver_profiles (
  profile_id, full_name, city, contact_phone, experience, skills, schedule,
  description, status, approved_at, rejection_reason, rejected_at,
  hidden_reason, hidden_at
) values
  (
    '00000000-0000-0000-0000-000000000008',
    'Legacy Rejected Caregiver', 'Chelyabinsk', '+700****0008', '5 years',
    array['hygiene care'], 'day shifts', 'Legacy rejected profile',
    'rejected', null, E'\t\n', clock_timestamp() + interval '1 second', null, null
  ),
  (
    '00000000-0000-0000-0000-000000000009',
    'Legacy Hidden Caregiver', 'Chelyabinsk', '+700****0009', '5 years',
    array['hygiene care'], 'day shifts', 'Legacy hidden profile',
    'hidden', clock_timestamp() + interval '1 second', null, null,
    E'\t\n', clock_timestamp() + interval '1 second'
  ),
  (
    '00000000-0000-0000-0000-000000000010',
    E'\t\n', 'Chelyabinsk', '+700****0010', '5 years',
    array['hygiene care'], 'day shifts', 'Legacy approved whitespace profile',
    'approved', clock_timestamp() + interval '1 second', null, null, null, null
  );
SQL
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260713100000_harden_profile_text_and_visibility.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260713110000_restrict_caregiver_projection_and_admin_bootstrap.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/002_rls_policies_test.sql"
