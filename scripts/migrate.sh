#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

readonly -a DATABASES=(
  "customerdb"
  "accountsdb"
  "billerdb"
  "paymentdb"
  "settlementdb"
  "billpayworkerdb"
)

readonly -a ACTIONS=(
  "migrate"
  "info"
  "validate"
  "repair"
)

FLYWAY_HOST="${FLYWAY_HOST:-localhost}"
FLYWAY_PORT="${FLYWAY_PORT:-5432}"
FLYWAY_USER="${FLYWAY_USER:-postgres}"
FLYWAY_PASSWORD="${FLYWAY_PASSWORD:-1}"
FLYWAY_SCHEMA="${FLYWAY_SCHEMA:-}"
SELECTED_DATABASE=""
SELECTED_ACTION=""
RUN_ALL=false
SKIP_CONFIRM=false

usage() {
  cat <<'EOF'
Usage: migrate.sh [options]

Interactive Flyway runner for MyYuumi ecommerce databases.

When action is migrate, runs scripts/init-dbs.sh first (CREATE DATABASE via init/).

Options:
  -d, --database NAME   Database name (e.g. customerdb) or "all"
  -s, --schema NAME     PostgreSQL schema (default: public)
  -a, --action ACTION   Flyway goal: migrate | info | validate | repair
  -H, --host HOST       PostgreSQL host (default: localhost)
  -P, --port PORT       PostgreSQL port (default: 5432)
  -u, --user USER       PostgreSQL user (default: postgres)
  -p, --password PASS   PostgreSQL password (default: 1)
  -y, --yes             Skip confirmation prompt
  -h, --help            Show this help

Environment variables (same names as flags):
  FLYWAY_HOST, FLYWAY_PORT, FLYWAY_USER, FLYWAY_PASSWORD, FLYWAY_SCHEMA

Examples:
  ./scripts/migrate.sh
  ./scripts/migrate.sh -d accountsdb -s public -a migrate -y
  ./scripts/migrate.sh -d all -a migrate -y
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' is not installed or not on PATH." >&2
    exit 1
  fi
}

is_valid_database() {
  local candidate="$1"
  local db
  for db in "${DATABASES[@]}"; do
    if [[ "${db}" == "${candidate}" ]]; then
      return 0
    fi
  done
  return 1
}

is_valid_action() {
  local candidate="$1"
  local action
  for action in "${ACTIONS[@]}"; do
    if [[ "${action}" == "${candidate}" ]]; then
      return 0
    fi
  done
  return 1
}

print_menu() {
  local title="$1"
  shift
  local -a items=("$@")

  echo ""
  echo "${title}"
  echo "----------------------------------------"
  local index=1
  local item
  for item in "${items[@]}"; do
    printf "  %2d) %s\n" "${index}" "${item}"
    index=$((index + 1))
  done
  echo "----------------------------------------"
}

read_menu_choice() {
  local max="$1"
  local prompt="$2"
  local choice=""

  while true; do
    read -r -p "${prompt} [1-${max}]: " choice
    if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= max )); then
      echo "${choice}"
      return 0
    fi
    echo "Invalid choice. Enter a number between 1 and ${max}."
  done
}

list_schemas_from_db() {
  if [[ -z "${SELECTED_DATABASE}" ]]; then
    return 1
  fi

  if ! command -v psql >/dev/null 2>&1; then
    return 1
  fi

  PGPASSWORD="${FLYWAY_PASSWORD}" psql \
    -h "${FLYWAY_HOST}" \
    -p "${FLYWAY_PORT}" \
    -U "${FLYWAY_USER}" \
    -d "${SELECTED_DATABASE}" \
    -Atqc "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema') ORDER BY schema_name;" \
    2>/dev/null || return 1
}

select_database_interactive() {
  local -a menu_items=("${DATABASES[@]}" "all")
  print_menu "Select database" "${menu_items[@]}"
  local choice
  choice="$(read_menu_choice "${#menu_items[@]}" "Database")"

  if (( choice == ${#menu_items[@]} )); then
    RUN_ALL=true
    SELECTED_DATABASE=""
    return 0
  fi

  SELECTED_DATABASE="${DATABASES[$((choice - 1))]}"
  RUN_ALL=false
}

select_schema_interactive() {
  local default_schema="public"

  if [[ "${RUN_ALL}" == true ]]; then
    read -r -p "Schema [${default_schema}]: " schema_input
    FLYWAY_SCHEMA="${schema_input:-${default_schema}}"
    return 0
  fi

  echo ""
  echo "Schema for database '${SELECTED_DATABASE}'"

  local -a schemas=()
  local schema_line
  while IFS= read -r schema_line; do
    [[ -n "${schema_line}" ]] && schemas+=("${schema_line}")
  done < <(list_schemas_from_db || true)

  if ((${#schemas[@]} > 0)); then
    print_menu "Available schemas" "${schemas[@]}" "custom")
    local choice
    choice="$(read_menu_choice "$((${#schemas[@]} + 1))" "Schema")"

    if (( choice == ${#schemas[@]} + 1 )); then
      read -r -p "Enter schema name [${default_schema}]: " schema_input
      FLYWAY_SCHEMA="${schema_input:-${default_schema}}"
      return 0
    fi

    FLYWAY_SCHEMA="${schemas[$((choice - 1))]}"
    return 0
  fi

  read -r -p "Schema [${default_schema}]: " schema_input
  FLYWAY_SCHEMA="${schema_input:-${default_schema}}"
}

select_action_interactive() {
  print_menu "Select Flyway action" "${ACTIONS[@]}"
  local choice
  choice="$(read_menu_choice "${#ACTIONS[@]}" "Action")"
  SELECTED_ACTION="${ACTIONS[$((choice - 1))]}"
}

confirm_run() {
  if [[ "${SKIP_CONFIRM}" == true ]]; then
    return 0
  fi

  echo ""
  echo "Summary"
  echo "  Host:     ${FLYWAY_HOST}:${FLYWAY_PORT}"
  echo "  User:     ${FLYWAY_USER}"
  if [[ "${RUN_ALL}" == true ]]; then
    echo "  Database: all (${DATABASES[*]})"
  else
    echo "  Database: ${SELECTED_DATABASE}"
  fi
  echo "  Schema:   ${FLYWAY_SCHEMA}"
  echo "  Action:   flyway:${SELECTED_ACTION}"
  echo ""

  read -r -p "Proceed? [y/N]: " answer
  case "${answer}" in
    y|Y|yes|YES) return 0 ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
}

run_flyway_for_database() {
  local database="$1"

  echo ""
  echo "==> ${database} (schema: ${FLYWAY_SCHEMA})"

  mvn -f "${PROJECT_DIR}/pom.xml" \
    -q \
    "flyway:${SELECTED_ACTION}" \
    "-P${database}" \
    "-Dflyway.host=${FLYWAY_HOST}" \
    "-Dflyway.port=${FLYWAY_PORT}" \
    "-Dflyway.user=${FLYWAY_USER}" \
    "-Dflyway.password=${FLYWAY_PASSWORD}" \
    "-Dflyway.database=${database}" \
    "-Dflyway.schemas=${FLYWAY_SCHEMA}" \
    "-Dflyway.locations=filesystem:migration/${database}"
}

run_database_init() {
  if [[ "${SELECTED_ACTION}" != "migrate" ]]; then
    return 0
  fi

  local init_script="${SCRIPT_DIR}/init-dbs.sh"
  if [[ ! -x "${init_script}" && -f "${init_script}" ]]; then
    chmod +x "${init_script}" || true
  fi

  if [[ ! -f "${init_script}" ]]; then
    echo "Warning: ${init_script} not found; skipping database init." >&2
    return 0
  fi

  echo ""
  echo "==> Ensuring databases exist (init/)"
  FLYWAY_HOST="${FLYWAY_HOST}" \
  FLYWAY_PORT="${FLYWAY_PORT}" \
  FLYWAY_USER="${FLYWAY_USER}" \
  FLYWAY_PASSWORD="${FLYWAY_PASSWORD}" \
    bash "${init_script}"
}

run_selected() {
  run_database_init

  if [[ "${RUN_ALL}" == true ]]; then
    local database
    for database in "${DATABASES[@]}"; do
      run_flyway_for_database "${database}"
    done
    return 0
  fi

  run_flyway_for_database "${SELECTED_DATABASE}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--database)
        [[ $# -ge 2 ]] || { echo "Missing value for ${1}" >&2; exit 1; }
        if [[ "$2" == "all" ]]; then
          RUN_ALL=true
          SELECTED_DATABASE=""
        elif is_valid_database "$2"; then
          SELECTED_DATABASE="$2"
          RUN_ALL=false
        else
          echo "Unknown database: $2" >&2
          exit 1
        fi
        shift 2
        ;;
      -s|--schema)
        [[ $# -ge 2 ]] || { echo "Missing value for ${1}" >&2; exit 1; }
        FLYWAY_SCHEMA="$2"
        shift 2
        ;;
      -a|--action)
        [[ $# -ge 2 ]] || { echo "Missing value for ${1}" >&2; exit 1; }
        if ! is_valid_action "$2"; then
          echo "Unknown action: $2 (expected: ${ACTIONS[*]})" >&2
          exit 1
        fi
        SELECTED_ACTION="$2"
        shift 2
        ;;
      -H|--host)
        [[ $# -ge 2 ]] || { echo "Missing value for ${1}" >&2; exit 1; }
        FLYWAY_HOST="$2"
        shift 2
        ;;
      -P|--port)
        [[ $# -ge 2 ]] || { echo "Missing value for ${1}" >&2; exit 1; }
        FLYWAY_PORT="$2"
        shift 2
        ;;
      -u|--user)
        [[ $# -ge 2 ]] || { echo "Missing value for ${1}" >&2; exit 1; }
        FLYWAY_USER="$2"
        shift 2
        ;;
      -p|--password)
        [[ $# -ge 2 ]] || { echo "Missing value for ${1}" >&2; exit 1; }
        FLYWAY_PASSWORD="$2"
        shift 2
        ;;
      -y|--yes)
        SKIP_CONFIRM=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  require_command mvn

  cd "${PROJECT_DIR}"

  if [[ "${RUN_ALL}" == false && -z "${SELECTED_DATABASE}" ]]; then
    select_database_interactive
  fi

  if [[ -z "${FLYWAY_SCHEMA}" ]]; then
    select_schema_interactive
  fi

  if [[ -z "${SELECTED_ACTION}" ]]; then
    select_action_interactive
  fi

  confirm_run
  run_selected

  echo ""
  echo "Done."
}

main "$@"
