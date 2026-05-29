#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/tmp/pgdata"

if [[ -d "${DATA_DIR}" ]]; then
  pg_ctl -D "${DATA_DIR}" stop
fi
