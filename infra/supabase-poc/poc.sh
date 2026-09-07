#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(realpath -- "${BASH_SOURCE[0]}")"
ROOT="$(dirname "$SCRIPT_PATH")"
REPO_ROOT="$(realpath -- "$ROOT/../..")"
PROJECT="$ROOT/.runtime/project"
REPORTS="$ROOT/reports"
POC_PROJECT_NAME="care-platform-supabase-poc"
POC_LABEL="com.care-platform.synthetic-poc"
POC_LABEL_VALUE="issue-74"
POC_SENTINEL="$ROOT/.poc-sentinel"
RUNTIME_SENTINEL="$PROJECT/.poc-sentinel"
SERVICES=(mailpit db auth rest meta studio api-gw supavisor)
CONTAINER_NAMES=(
  care-platform-poc-mailpit
  care-platform-poc-db
  care-platform-poc-auth
  care-platform-poc-rest
  care-platform-poc-meta
  care-platform-poc-studio
  care-platform-poc-api-gw
  care-platform-poc-supavisor
)
NETWORK_NAMES=(care-platform-supabase-poc_default)
VOLUME_NAMES=(
  care-platform-supabase-poc_db-config
  care-platform-supabase-poc_deno-cache
)

validate_repo_and_sentinel() {
  local git_root expected_root sentinel
  git_root="$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: PoC cleanup root is not a Git repository" >&2
    return 2
  }
  git_root="$(realpath -- "$git_root")"
  expected_root="$(realpath -- "$REPO_ROOT/infra/supabase-poc")"
  [[ "$git_root" == "$REPO_ROOT" && "$expected_root" == "$ROOT" ]] || {
    echo "ERROR: canonical PoC repository path validation failed" >&2
    return 2
  }
  [[ -f "$REPO_ROOT/README.md" && -d "$REPO_ROOT/supabase/migrations" \
      && -f "$ROOT/provenance.env" && -f "$POC_SENTINEL" && ! -L "$POC_SENTINEL" ]] || {
    echo "ERROR: expected repository markers or PoC sentinel are missing" >&2
    return 2
  }
  sentinel="$(<"$POC_SENTINEL")"
  [[ "$sentinel" == "$POC_PROJECT_NAME:$POC_LABEL_VALUE" ]] || {
    echo "ERROR: PoC sentinel content is invalid" >&2
    return 2
  }
}

run_docker() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  elif sudo -n docker info >/dev/null 2>&1; then
    sudo -n docker "$@"
  else
    echo "ERROR: Docker daemon is unavailable to this user" >&2
    return 2
  fi
}

compose() {
  run_docker compose --project-name "$POC_PROJECT_NAME" \
    --project-directory "$PROJECT" --env-file "$PROJECT/.env" \
    --file "$PROJECT/docker-compose.yml" --file "$PROJECT/compose.poc.yml" "$@"
}

require_runtime() {
  validate_repo_and_sentinel
  [[ -f "$PROJECT/.env" && -f "$PROJECT/docker-compose.yml" \
      && -f "$PROJECT/compose.poc.yml" && -f "$RUNTIME_SENTINEL" \
      && ! -L "$RUNTIME_SENTINEL" ]] || {
    echo "ERROR: runtime is missing or partial; run '$0 prepare' or verified destroy" >&2
    exit 2
  }
  [[ "$(<"$RUNTIME_SENTINEL")" == "$POC_PROJECT_NAME:$POC_LABEL_VALUE" ]] || {
    echo "ERROR: runtime PoC sentinel is invalid" >&2
    exit 2
  }
  [[ "$(stat -c '%a' "$PROJECT/.env")" == "600" ]] || {
    echo "ERROR: runtime .env must have mode 600" >&2
    exit 2
  }
}

project_resource_ids() {
  local resource_type="$1"
  case "$resource_type" in
    container)
      run_docker container ls -aq --no-trunc \
        --filter "label=com.docker.compose.project=$POC_PROJECT_NAME"
      ;;
    network)
      run_docker network ls -q --no-trunc \
        --filter "label=com.docker.compose.project=$POC_PROJECT_NAME"
      ;;
    volume)
      run_docker volume ls -q --filter "label=com.docker.compose.project=$POC_PROJECT_NAME"
      ;;
    *)
      echo "ERROR: unsupported Docker resource type" >&2
      return 2
      ;;
  esac
}

resource_labels() {
  local resource_type="$1" resource_id="$2"
  case "$resource_type" in
    container)
      run_docker container inspect --format \
        '{{ index .Config.Labels "com.docker.compose.project" }}|{{ index .Config.Labels "com.care-platform.synthetic-poc" }}' \
        "$resource_id"
      ;;
    network)
      run_docker network inspect --format \
        '{{ index .Labels "com.docker.compose.project" }}|{{ index .Labels "com.care-platform.synthetic-poc" }}' \
        "$resource_id"
      ;;
    volume)
      run_docker volume inspect --format \
        '{{ index .Labels "com.docker.compose.project" }}|{{ index .Labels "com.care-platform.synthetic-poc" }}' \
        "$resource_id"
      ;;
  esac
}

all_resource_references() {
  local resource_type="$1"
  case "$resource_type" in
    container)
      run_docker container ls -a --no-trunc --format '{{.ID}}|{{.Names}}'
      ;;
    network)
      run_docker network ls --no-trunc --format '{{.ID}}|{{.Name}}'
      ;;
    volume)
      run_docker volume ls --format '{{.Name}}'
      ;;
    *)
      echo "ERROR: unsupported Docker resource type" >&2
      return 2
      ;;
  esac
}

resource_exists() {
  local resource_type="$1" resource_id="$2" inventory line listed_id names
  if ! inventory="$(all_resource_references "$resource_type")"; then
    echo "ERROR: failed to list Docker resources after inspecting '$resource_id'" >&2
    return 2
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ "$resource_type" == volume ]]; then
      [[ "$line" == "$resource_id" ]] && return 0
      continue
    fi
    IFS='|' read -r listed_id names <<<"$line"
    [[ "$listed_id" == "$resource_id" ]] && return 0
    if [[ "$resource_type" == container && ",$names," == *",$resource_id,"* ]]; then
      return 0
    fi
    if [[ "$resource_type" == network && "$names" == "$resource_id" ]]; then
      return 0
    fi
  done <<<"$inventory"
  return 1
}

checked_resource_labels() {
  local resource_type="$1" resource_id="$2" labels status
  if labels="$(resource_labels "$resource_type" "$resource_id" 2>/dev/null)"; then
    printf '%s\n' "$labels"
    return 0
  fi
  if resource_exists "$resource_type" "$resource_id"; then
    echo "ERROR: failed to inspect existing $resource_type '$resource_id'" >&2
    return 2
  else
    status=$?
  fi
  ((status == 1)) && return 1
  return "$status"
}

verify_expected_container_ownership() {
  local name labels status
  for name in "${CONTAINER_NAMES[@]}"; do
    if labels="$(checked_resource_labels container "$name")"; then
      [[ "$labels" == "$POC_PROJECT_NAME|$POC_LABEL_VALUE" ]] || {
        echo "ERROR: expected PoC container name '$name' is owned by another stack" >&2
        return 2
      }
    else
      status=$?
      ((status == 1)) || return "$status"
    fi
  done
}

verify_reserved_resource_ownership() {
  local resource_type name labels status
  local -a names=()
  for resource_type in network volume; do
    if [[ "$resource_type" == network ]]; then
      names=("${NETWORK_NAMES[@]}")
    else
      names=("${VOLUME_NAMES[@]}")
    fi
    for name in "${names[@]}"; do
      if labels="$(checked_resource_labels "$resource_type" "$name")"; then
        [[ "$labels" == "$POC_PROJECT_NAME|$POC_LABEL_VALUE" ]] || {
          echo "ERROR: reserved PoC $resource_type '$name' is owned by another stack" >&2
          return 2
        }
      else
        status=$?
        ((status == 1)) || return "$status"
      fi
    done
  done
}

verify_owned_resources() {
  validate_repo_and_sentinel
  run_docker info >/dev/null
  verify_expected_container_ownership
  verify_reserved_resource_ownership

  local resource_type resource_id resource_ids labels status
  for resource_type in container network volume; do
    if ! resource_ids="$(project_resource_ids "$resource_type")"; then
      echo "ERROR: failed to list project $resource_type resources" >&2
      return 2
    fi
    while IFS= read -r resource_id; do
      [[ -n "$resource_id" ]] || continue
      if labels="$(checked_resource_labels "$resource_type" "$resource_id")"; then
        [[ "$labels" == "$POC_PROJECT_NAME|$POC_LABEL_VALUE" ]] || {
          echo "ERROR: refusing cleanup of unverified $resource_type '$resource_id'" >&2
          return 2
        }
      else
        status=$?
        ((status == 1)) || return "$status"
      fi
    done <<<"$resource_ids"
  done
}

remove_resource() {
  local resource_type="$1" resource_id="$2" labels status
  if labels="$(checked_resource_labels "$resource_type" "$resource_id")"; then
    [[ "$labels" == "$POC_PROJECT_NAME|$POC_LABEL_VALUE" ]] || {
      echo "ERROR: refusing cleanup of unverified $resource_type '$resource_id'" >&2
      return 2
    }
  else
    status=$?
    if ((status == 1)); then
      echo "Docker $resource_type '$resource_id' disappeared before deletion; continuing." >&2
      return 0
    fi
    return "$status"
  fi

  case "$resource_type" in
    container)
      run_docker container rm --force -- "$resource_id" >/dev/null || status=$?
      ;;
    network)
      run_docker network rm -- "$resource_id" >/dev/null || status=$?
      ;;
    volume)
      run_docker volume rm --force -- "$resource_id" >/dev/null || status=$?
      ;;
  esac
  if [[ -n "${status:-}" ]]; then
    if resource_exists "$resource_type" "$resource_id"; then
      echo "ERROR: failed to remove existing $resource_type '$resource_id'" >&2
      return "$status"
    else
      local exists_status=$?
      ((exists_status == 1)) && return 0
      return "$exists_status"
    fi
  fi
}

remove_owned_resources() {
  local resource_type resource_id resource_ids
  for resource_type in container network volume; do
    if ! resource_ids="$(project_resource_ids "$resource_type")"; then
      echo "ERROR: failed to list project $resource_type resources before deletion" >&2
      return 2
    fi
    while IFS= read -r resource_id; do
      [[ -n "$resource_id" ]] || continue
      remove_resource "$resource_type" "$resource_id"
    done <<<"$resource_ids"
  done
}

remove_local_artifacts() {
  local runtime_target reports_target
  runtime_target="$(realpath -m -- "$ROOT/.runtime")"
  reports_target="$(realpath -m -- "$ROOT/reports")"
  [[ "$runtime_target" == "$ROOT/.runtime" && "$reports_target" == "$ROOT/reports" ]] || {
    echo "ERROR: cleanup targets escaped the canonical PoC root" >&2
    return 2
  }
  if ! rm -rf -- "$runtime_target" "$reports_target"; then
    validate_repo_and_sentinel
    sudo -n rm -rf -- "$runtime_target" "$reports_target"
  fi
}

verify_docker_cleanup() {
  local resource_type remaining name labels status
  for resource_type in container network volume; do
    if ! remaining="$(project_resource_ids "$resource_type")"; then
      echo "ERROR: failed to verify project $resource_type cleanup" >&2
      return 2
    fi
    [[ -z "$remaining" ]] || {
      echo "ERROR: owned $resource_type resources remain after cleanup" >&2
      return 2
    }
  done
  for name in "${CONTAINER_NAMES[@]}"; do
    if labels="$(checked_resource_labels container "$name")"; then
      echo "ERROR: expected PoC container '$name' remains after cleanup" >&2
      return 2
    else
      status=$?
      ((status == 1)) || return "$status"
    fi
  done
  local -a names=()
  for resource_type in network volume; do
    if [[ "$resource_type" == network ]]; then
      names=("${NETWORK_NAMES[@]}")
    else
      names=("${VOLUME_NAMES[@]}")
    fi
    for name in "${names[@]}"; do
      if labels="$(checked_resource_labels "$resource_type" "$name")"; then
        echo "ERROR: reserved PoC $resource_type '$name' remains after cleanup" >&2
        return 2
      else
        status=$?
        ((status == 1)) || return "$status"
      fi
    done
  done
}

verify_cleanup() {
  verify_docker_cleanup
  [[ ! -e "$ROOT/.runtime" && ! -e "$ROOT/reports" ]] || {
    echo "ERROR: runtime secrets or reports remain after cleanup" >&2
    return 2
  }
}

destroy_poc() {
  validate_repo_and_sentinel
  if [[ -e "$ROOT/.runtime" ]] && ! {
    [[ -f "$PROJECT/.env" && -f "$PROJECT/docker-compose.yml" \
        && -f "$PROJECT/compose.poc.yml" && -f "$RUNTIME_SENTINEL" ]]
  }; then
    echo "Partial runtime detected; using verified label-scoped cleanup." >&2
  fi
  verify_owned_resources
  remove_owned_resources
  verify_docker_cleanup
  remove_local_artifacts
  verify_cleanup
  echo "Synthetic PoC containers, networks, volumes, runtime secrets and reports removed."
}

preflight() {
  command -v curl >/dev/null
  command -v python3 >/dev/null
  command -v openssl >/dev/null
  run_docker compose version >/dev/null
  local mem_kb disk_kb
  mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
  disk_kb=$(df -Pk "$ROOT" | awk 'NR == 2 {print $4}')
  (( mem_kb >= 3900000 )) || {
    echo "ERROR: complete-stack minimum is 4 GB RAM; detected ${mem_kb} KiB" >&2
    return 2
  }
  (( disk_kb >= 41943040 )) || {
    echo "ERROR: complete-stack minimum is 40 GB free disk" >&2
    return 2
  }
  echo "Preflight passed: Docker, Compose, RAM and free-disk minimums are present."
}

verify_bindings() {
  require_runtime
  local expected binding service port
  for spec in "api-gw 8000 127.0.0.1" "supavisor 5432 127.0.0.1" \
              "supavisor 6543 127.0.0.1" "mailpit 8025 127.0.0.1"; do
    read -r service port expected <<<"$spec"
    binding=$(compose port "$service" "$port")
    [[ "$binding" == "$expected:"* ]] || {
      echo "ERROR: $service:$port is not loopback-only" >&2
      return 2
    }
  done
  echo "Bindings verified: gateway, database pooler and mail UI are loopback-only."
}

apply_migrations() {
  require_runtime
  mkdir -p "$REPORTS"
  local marker="$REPORTS/migrations-applied.txt" name
  [[ ! -e "$marker" ]] || {
    echo "ERROR: migrations were already applied; use a fresh runtime for a repeatable run" >&2
    return 2
  }
  : >"$marker.tmp"
  chmod 600 "$marker.tmp"
  for migration in "$REPO_ROOT"/supabase/migrations/*.sql; do
    name=$(basename "$migration")
    echo "Applying $name"
    compose exec -T db psql --username postgres --dbname postgres \
      --set ON_ERROR_STOP=1 <"$migration" >/dev/null
    printf '%s\n' "$name" >>"$marker.tmp"
  done
  mv "$marker.tmp" "$marker"
  echo "All repository migrations applied to the real self-hosted database."
}

write_report() {
  require_runtime
  mkdir -p "$REPORTS"
  local report="$REPORTS/runtime-report.txt" ids
  {
    date --iso-8601=seconds
    echo "Services: ${SERVICES[*]}"
    echo "Docker: $(run_docker version --format '{{.Server.Version}}')"
    echo "Compose: $(run_docker compose version --short)"
    echo "Host memory: $(awk '/MemTotal:/ {print $2 " KiB"}' /proc/meminfo)"
    echo "Host free disk: $(df -Pk "$ROOT" | awk 'NR == 2 {print $4 " KiB"}')"
    echo "Container status:"
    compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
    echo "Container resource snapshot:"
    ids=$(compose ps -q)
    if [[ -n "$ids" ]]; then
      # shellcheck disable=SC2086
      run_docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}' $ids
    fi
  } >"$report"
  chmod 600 "$report"
  echo "Sanitized runtime report written to $report"
}

case "${1:-help}" in
  prepare)
    validate_repo_and_sentinel
    python3 "$ROOT/scripts/prepare_runtime.py"
    ;;
  preflight)
    validate_repo_and_sentinel
    preflight
    ;;
  start)
    require_runtime
    preflight
    verify_expected_container_ownership
    verify_reserved_resource_ownership
    compose config --quiet
    compose pull "${SERVICES[@]}"
    compose up -d --wait "${SERVICES[@]}"
    verify_bindings
    ;;
  migrate)
    apply_migrations
    ;;
  smoke)
    require_runtime
    python3 "$ROOT/scripts/smoke_test.py"
    ;;
  report)
    write_report
    ;;
  stop)
    require_runtime
    verify_owned_resources
    compose down
    ;;
  destroy)
    [[ "${2:-}" == "--confirm-destroy" ]] || {
      echo "ERROR: destructive cleanup requires --confirm-destroy" >&2
      exit 2
    }
    destroy_poc
    ;;
  all)
    validate_repo_and_sentinel
    python3 "$ROOT/scripts/prepare_runtime.py"
    require_runtime
    preflight
    verify_expected_container_ownership
    verify_reserved_resource_ownership
    compose config --quiet
    compose pull "${SERVICES[@]}"
    compose up -d --wait "${SERVICES[@]}"
    verify_bindings
    apply_migrations
    python3 "$ROOT/scripts/smoke_test.py"
    write_report
    ;;
  help|-h|--help)
    echo "Usage: $0 prepare|preflight|start|migrate|smoke|report|stop|destroy --confirm-destroy|all"
    ;;
  *)
    echo "ERROR: unknown command '${1:-}'" >&2
    exit 2
    ;;
esac
