#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4000}"
TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-60}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

json_get() {
  local path="$1"
  python3 -c "import json,sys; data=json.load(sys.stdin); cur=data
for part in '${path}'.split('.'):
    cur = cur[int(part)] if isinstance(cur, list) else cur[part]
print(cur)"
}

wait_for_ready() {
  local deadline=$((SECONDS + TIMEOUT_SECONDS))

  until curl -fsS "${BASE_URL}/readyz" >/dev/null; do
    if (( SECONDS >= deadline )); then
      echo "ReportForge did not become ready within ${TIMEOUT_SECONDS}s" >&2
      curl -sS "${BASE_URL}/readyz" || true
      exit 1
    fi

    sleep 1
  done
}

wait_for_report() {
  local token="$1"
  local report_id="$2"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  local response_file="${tmp_dir}/report.json"

  while true; do
    curl -fsS -H "x-api-key: ${token}" "${BASE_URL}/api/v1/reports/${report_id}" >"${response_file}"
    status="$(json_get "data.status" <"${response_file}")"

    case "${status}" in
      succeeded)
        return 0
        ;;
      failed|cancelled)
        echo "Report ${report_id} reached terminal status ${status}" >&2
        cat "${response_file}" >&2
        exit 1
        ;;
    esac

    if (( SECONDS >= deadline )); then
      echo "Report ${report_id} did not succeed within ${TIMEOUT_SECONDS}s" >&2
      cat "${response_file}" >&2
      exit 1
    fi

    sleep 1
  done
}

require_command curl
require_command python3

wait_for_ready
curl -fsS "${BASE_URL}/healthz" >/dev/null
curl -fsS "${BASE_URL}/metrics" | grep -q "reportforge_http_requests_total"

unique="$(date +%s)-${RANDOM}"
organization_payload="${tmp_dir}/organization.json"
report_payload="${tmp_dir}/report.json"
organization_response="${tmp_dir}/organization-response.json"
report_response="${tmp_dir}/report-response.json"
download_response="${tmp_dir}/download-response.json"
artifact_file="${tmp_dir}/artifact.csv"

cat >"${organization_payload}" <<JSON
{
  "organization": {
    "name": "Smoke Test ${unique}",
    "slug": "smoke-test-${unique}",
    "retention_days": 7
  }
}
JSON

curl -fsS \
  -H "content-type: application/json" \
  -d @"${organization_payload}" \
  "${BASE_URL}/api/v1/organizations" >"${organization_response}"

token="$(json_get "data.bootstrap_api_key" <"${organization_response}")"

cat >"${report_payload}" <<JSON
{
  "report": {
    "template_name": "cash_position",
    "format": "csv",
    "requested_by": "smoke@example.com",
    "idempotency_key": "smoke-${unique}",
    "filters": {
      "row_limit": 3
    }
  }
}
JSON

curl -fsS \
  -H "content-type: application/json" \
  -H "x-api-key: ${token}" \
  -d @"${report_payload}" \
  "${BASE_URL}/api/v1/reports" >"${report_response}"

report_id="$(json_get "data.id" <"${report_response}")"
wait_for_report "${token}" "${report_id}"

curl -fsS \
  -H "x-api-key: ${token}" \
  "${BASE_URL}/api/v1/reports/${report_id}/download" >"${download_response}"

download_url="$(json_get "data.url" <"${download_response}")"
curl -fsSL "${download_url}" -o "${artifact_file}"
grep -q "as_of_date" "${artifact_file}"

echo "Smoke test passed for report ${report_id}."
