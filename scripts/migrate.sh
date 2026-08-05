#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

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
FLYWAY_ENV="${FLYWAY_ENV:-local}"
SELECTED_DATABASE=""
SELECTED_ACTION=""
RUN_ALL=false
SKIP_CONFIRM=false
DATABASES=()

usage() {
  cat <<'EOF'
Usage: migrate.sh [options]

Interactive Flyway runner for MyYuumi ecommerce databases (nexthcm-migration style).

Per-database settings live in config/<env>/flyway_<database>.conf — not in pom.xml.
When action is migrate, runs scripts/init-dbs.sh first (CREATE DATABASE via init/).

Options:
  -d, --database NAME   Database name (e.g. accountdb) or "all"
  -e, --env NAME        Config env folder under config/ (default: local)
  -s, --schema NAME     Override flyway.schemas from conf (optional)
  -a, --action ACTION   Flyway goal: migrate | info | validate | repair
  -H, --host HOST       Override host (also sets FLYWAY_HOST for init)
  -P, --port PORT       Override port
  -u, --user USER       Override user
  -p, --password PASS   Override password
  -y, --yes             Skip confirmation prompt
  -h, --help            Show this help

Examples:
  ./scripts/migrate.sh
  ./scripts/migrate.sh -d accountdb -a migrate -y
  ./scripts/migrate.sh -d all -e local -a migrate -y

Maven equivalent:
  mvn flyway:migrate -Dflyway.configFiles=$PWD/config/local/flyway_accountdb.conf
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' is not installed or not on PATH." >&2
    exit 1
  fi
}

load_databases_from_config() {
  local config_dir="${PROJECT_DIR}/config/${FLYWAY_ENV}"
  DATABASES=()

  if [[ ! -d "${config_dir}" ]]; then
    echo "Error: config env folder not found: ${config_dir}" >&2
    exit 1
  fi

  local conf
  for conf in "${config_dir}"/flyway_*.conf; do
    [[ -f "${conf}" ]] || continue
    local base
    base="$(basename "${conf}")"
    local db="${base#flyway_}"
    db="${db%.conf}"
    DATABASES+=("${db}")
  done

  if ((${#DATABASES[@]} == 0)); then
    echo "Error: no flyway_*.conf files under ${config_dir}" >&2
    exit 1
  fi

  IFS=$'\n' DATABASES=($(printf '%s\n' "${DATABASES[@]}" | sort))
  unset IFS
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
  print_menu "Select database (from config/${FLYWAY_ENV})" "${menu_items[@]}"
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
    read -r -p "Override schema (blank = use conf) [${default_schema}]: " schema_input
    if [[ -n "${schema_input}" ]]; then
      FLYWAY_SCHEMA="${schema_input}"
    fi
    return 0
  fi

  echo ""
  echo "Schema for database '${SELECTED_DATABASE}' (blank = use conf)"

  local -a schemas=()
  local schema_line
  while IFS= read -r schema_line; do
    [[ -n "${schema_line}" ]] && schemas+=("${schema_line}")
  done < <(list_schemas_from_db || true)

  if ((${#schemas[@]} > 0)); then
    print_menu "Available schemas" "${schemas[@]}" "use conf / custom")
    local choice
    choice="$(read_menu_choice "$((${#schemas[@]} + 1))" "Schema")"

    if (( choice == ${#schemas[@]} + 1 )); then
      read -r -p "Enter schema name (blank = use conf): " schema_input
      FLYWAY_SCHEMA="${schema_input}"
      return 0
    fi

    FLYWAY_SCHEMA="${schemas[$((choice - 1))]}"
    return 0
  fi

  read -r -p "Schema (blank = use conf): " schema_input
  FLYWAY_SCHEMA="${schema_input}"
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
  echo "  Env:      ${FLYWAY_ENV}"
  echo "  Host:     ${FLYWAY_HOST}:${FLYWAY_PORT} (init / overrides)"
  echo "  User:     ${FLYWAY_USER}"
  if [[ "${RUN_ALL}" == true ]]; then
    echo "  Database: all (${DATABASES[*]})"
  else
    echo "  Database: ${SELECTED_DATABASE}"
    echo "  Config:   config/${FLYWAY_ENV}/flyway_${SELECTED_DATABASE}.conf"
  fi
  if [[ -n "${FLYWAY_SCHEMA}" ]]; then
    echo "  Schema:   ${FLYWAY_SCHEMA} (override)"
  else
    echo "  Schema:   (from conf)"
  fi
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
  local config_file="${PROJECT_DIR}/config/${FLYWAY_ENV}/flyway_${database}.conf"

  if [[ ! -f "${config_file}" ]]; then
    echo "Error: missing Flyway config: ${config_file}" >&2
    exit 1
  fi

  echo ""
  echo "==> ${database} (config/${FLYWAY_ENV}/flyway_${database}.conf)"

  local -a mvn_args=(
    -f "${PROJECT_DIR}/pom.xml"
    -q
    "flyway:${SELECTED_ACTION}"
    "-Dflyway.configFiles=${config_file}"
  )

  if [[ -n "${FLYWAY_SCHEMA}" ]]; then
    mvn_args+=("-Dflyway.schemas=${FLYWAY_SCHEMA}")
  fi

  # Optional connection overrides (useful for CI / docker host)
  if [[ -n "${FLYWAY_HOST}" ]]; then
    mvn_args+=("-Dflyway.url=jdbc:postgresql://${FLYWAY_HOST}:${FLYWAY_PORT}/${database}")
  fi
  if [[ -n "${FLYWAY_USER}" ]]; then
    mvn_args+=("-Dflyway.user=${FLYWAY_USER}")
  fi
  if [[ -n "${FLYWAY_PASSWORD}" ]]; then
    mvn_args+=("-Dflyway.password=${FLYWAY_PASSWORD}")
  fi

  mvn "${mvn_args[@]}"
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
        else
          SELECTED_DATABASE="$2"
          RUN_ALL=false
        fi
        shift 2
        ;;
      -e|--env)
        [[ $# -ge 2 ]] || { echo "Missing value for ${1}" >&2; exit 1; }
        FLYWAY_ENV="$2"
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

  load_databases_from_config

  if [[ "${RUN_ALL}" == false && -n "${SELECTED_DATABASE}" ]]; then
    if ! is_valid_database "${SELECTED_DATABASE}"; then
      echo "Unknown database: ${SELECTED_DATABASE}" >&2
      echo "Known (config/${FLYWAY_ENV}): ${DATABASES[*]}" >&2
      exit 1
    fi
  fi

  if [[ "${RUN_ALL}" == false && -z "${SELECTED_DATABASE}" ]]; then
    select_database_interactive
  fi

  if [[ -z "${SELECTED_ACTION}" ]]; then
    select_action_interactive
  fi

  # Only prompt for schema override when interactive and not already set via -s
  if [[ "${SKIP_CONFIRM}" == false && -z "${FLYWAY_SCHEMA}" ]]; then
    select_schema_interactive
  fi

  confirm_run
  run_selected

  echo ""
  echo "Done."
}

main "$@"
