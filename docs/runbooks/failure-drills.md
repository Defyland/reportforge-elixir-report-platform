# Failure Drills

These drills target the local production-like stack in [docker-compose.yml](../../docker-compose.yml). They prove operational behavior without requiring cloud infrastructure.

Start the stack:

```sh
docker compose up -d --build
BASE_URL=http://localhost:4000 bash scripts/smoke.sh
```

## Object Storage Outage

Purpose: prove report generation classifies storage outages as transient failures.

```sh
docker compose stop minio
BASE_URL=http://localhost:4000 bash scripts/smoke.sh
docker compose start minio
```

Expected result:

- smoke test fails during artifact creation or download
- report events include `report.retry_scheduled` when the worker encounters `storage_unavailable`
- Prometheus eventually records `reportforge_report_retries_total`

Recovery:

```sh
docker compose start minio
BASE_URL=http://localhost:4000 bash scripts/smoke.sh
```

## Database Outage

Purpose: prove readiness fails when PostgreSQL is unavailable.

```sh
docker compose stop postgres
curl -i http://localhost:4000/readyz
docker compose start postgres
```

Expected result:

- `/readyz` returns `503`
- readiness payload marks `database` as down
- `/healthz` can still return process liveness

## Queue Backlog

Purpose: prove queue backlog is visible before treating it as an application outage.

```sh
curl -fsS http://localhost:4000/metrics | grep reportforge_inflight_reports
curl -fsS http://localhost:9090/api/v1/rules | grep ReportForgeQueueBacklog
```

Expected result:

- queued/running reports are reflected by `reportforge_inflight_reports`
- Prometheus loads the `ReportForgeQueueBacklog` alert rule

## Expired Download URL

Purpose: prove signed URL expiry returns a terminal client-visible status.

Steps:

1. Generate a report with `scripts/smoke.sh`.
2. Lower `REPORT_FORGE_S3_PRESIGN_TTL_SECONDS` or report TTL in a controlled environment.
3. Request the old `/downloads/{token}` URL after expiry.

Expected result:

- the service returns `410` for expired ReportForge signed URLs
- clients must re-resolve a fresh link through `GET /api/v1/reports/{id}/download`

## Alert Rule Validation

Purpose: prove alert rules are loaded and queryable.

```sh
curl -fsS http://localhost:9090/api/v1/rules | grep ReportForgeTargetDown
curl -fsS http://localhost:9090/api/v1/targets | grep reportforge
```

Expected result:

- Prometheus reports the `reportforge` scrape target
- Prometheus loads the ReportForge alert group from [ops/prometheus/alerts.yml](../../ops/prometheus/alerts.yml)
