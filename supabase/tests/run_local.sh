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

required_files=(
  "supabase/migrations/20260710160000_initial_schema.sql"
  "supabase/migrations/20260710161000_profile_statuses.sql"
  "supabase/migrations/20260712130000_require_meaningful_caregiver_skills.sql"
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
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/20260712130000_require_meaningful_caregiver_skills.sql"
sudo -u postgres psql --set=ON_ERROR_STOP=1 --dbname="$db_name" \
  --file="$tmp_dir/001_initial_schema_test.sql"
