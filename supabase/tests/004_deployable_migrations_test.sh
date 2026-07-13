#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
expected_migrations=(
  "20260710160000_initial_schema.sql"
  "20260710161000_profile_statuses.sql"
  "20260710162000_rls_policies.sql"
  "20260710163000_auth_foundation.sql"
  "20260712115500_caregiver_profile_editability.sql"
  "20260712130000_require_meaningful_caregiver_skills.sql"
  "20260712140000_repair_legacy_meaningful_skills.sql"
  "20260712150000_repair_hidden_meaningful_skills.sql"
  "20260713100000_harden_profile_text_and_visibility.sql"
)

for migration in "${expected_migrations[@]}"; do
  if [[ ! -f "$repo_root/supabase/migrations/$migration" ]]; then
    echo "Missing deployable migration: $migration" >&2
    exit 1
  fi
done

if [[ -e "$repo_root/supabase/seed/001_profile_statuses.sql" ]]; then
  echo "Required profile status rows must be deployed from migrations, not a custom seed path" >&2
  exit 1
fi

echo "Supabase deployment migration layout tests passed"
