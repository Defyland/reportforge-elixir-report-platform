#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/tmp/pgdata"
LOG_FILE="${ROOT_DIR}/tmp/postgres.log"
PORT="${REPORT_FORGE_DB_PORT:-55432}"
USER_NAME="${REPORT_FORGE_DB_USER:-postgres}"

mkdir -p "${ROOT_DIR}/tmp"

if [[ ! -d "${DATA_DIR}" ]]; then
  initdb -D "${DATA_DIR}" -A trust -U "${USER_NAME}" >/dev/null
fi

pg_ctl -D "${DATA_DIR}" -l "${LOG_FILE}" -o "-p ${PORT}" start

createdb -h 127.0.0.1 -p "${PORT}" -U "${USER_NAME}" report_forge_dev 2>/dev/null || true
createdb -h 127.0.0.1 -p "${PORT}" -U "${USER_NAME}" report_forge_test 2>/dev/null || true

echo "Local Postgres started on port ${PORT}."
