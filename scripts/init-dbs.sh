#!/usr/bin/env bash
set -euo pipefail

# Create empty PostgreSQL databases (nexthcm-migration style).
# Run against the maintenance DB "postgres" before Flyway schema migrations.
#
# Usage:
#   ./scripts/init-dbs.sh
#   FLYWAY_HOST=localhost FLYWAY_PASSWORD=1 ./scripts/init-dbs.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INIT_DIR="${PROJECT_DIR}/init"

FLYWAY_HOST="${FLYWAY_HOST:-localhost}"
FLYWAY_PORT="${FLYWAY_PORT:-5432}"
FLYWAY_USER="${FLYWAY_USER:-postgres}"
FLYWAY_PASSWORD="${FLYWAY_PASSWORD:-1}"

if ! command -v psql >/dev/null 2>&1; then
  echo "Error: 'psql' is required to run init scripts." >&2
  exit 1
fi

if [[ ! -d "${INIT_DIR}" ]]; then
  echo "Error: init directory not found: ${INIT_DIR}" >&2
  exit 1
fi

export PGPASSWORD="${FLYWAY_PASSWORD}"

echo "Initializing databases on ${FLYWAY_HOST}:${FLYWAY_PORT} as ${FLYWAY_USER}"
echo "Init dir: ${INIT_DIR}"
echo ""

shopt -s nullglob
scripts=("${INIT_DIR}"/*/V*__init_database.sql)

if ((${#scripts[@]} == 0)); then
  echo "No init scripts found under ${INIT_DIR}/*/V*__init_database.sql"
  exit 1
fi

# Sort so keycloak/app DBs run in a stable path order
IFS=$'\n' sorted_scripts=($(printf '%s\n' "${scripts[@]}" | sort))
unset IFS

for script in "${sorted_scripts[@]}"; do
  echo "==> ${script#${PROJECT_DIR}/}"
  psql \
    -h "${FLYWAY_HOST}" \
    -p "${FLYWAY_PORT}" \
    -U "${FLYWAY_USER}" \
    -d postgres \
    -v ON_ERROR_STOP=1 \
    -f "${script}"
done

echo ""
echo "Database init complete."
