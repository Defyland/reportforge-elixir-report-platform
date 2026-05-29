# Common Issues Runbook

## Report stays queued

Checks:

- call `GET /readyz`
- inspect `/metrics` for `reportforge_inflight_reports`
- verify the process has not restarted since report creation

Likely cause in this slice:

- the Oban queue is paused or workers are not draining jobs
- the database is reachable enough for requests but not for queue execution
- the report is blocked behind queue backpressure

## Report failed with `source_timeout`

Meaning:

- the report used the failure simulation path for an upstream query timeout

Action:

- inspect report events
- retry the report only after removing the simulated failure input

## Download URL returns `410`

Meaning:

- the signed artifact URL expired

Action:

- re-resolve the download link through `GET /api/v1/reports/{id}/download`
- if the report itself has expired in a future persistence phase, regenerate it

## Tenant receives `404` for an existing report

Meaning:

- the report belongs to another organization or the ID is wrong

Action:

- confirm the API key belongs to the expected tenant
- inspect `GET /api/v1/organizations/me`

## Frequent `429` responses

Meaning:

- the fixed-window rate limiter is being hit

Action:

- slow the client submission rate
- spread scheduler bursts
- tune the tenant limits only with benchmark evidence

## Cleanup job does not remove expired artifacts

Checks:

- verify `GET /readyz` is healthy
- inspect `/metrics` and the logs for `maintenance_cleanup_completed`
- confirm the `maintenance` Oban queue is enabled and draining

Likely cause in this slice:

- the process is running without the scheduled maintenance queue
- artifact or report timestamps are newer than the current cleanup cutoff
- the database is reachable for requests but failing during background maintenance

Action:

- enqueue `purge_expired_artifacts` or `purge_retained_reports` manually in a console
- confirm the target rows are actually expired or outside the tenant retention window
- inspect audit logs for `maintenance.purge_expired_artifacts` or `maintenance.purge_retained_reports`

## Service fails to boot in production with signing-secret error

Meaning:

- `SIGNING_SECRET` and `SIGNING_SECRET_FILE` are both missing

Action:

- provide `SIGNING_SECRET` directly for a quick recovery
- prefer `SIGNING_SECRET_FILE` when using mounted secret files
- restart the service only after one of those sources is present

## Database outage affects requests and workers

Checks:

- call `GET /readyz`
- inspect request errors and Oban worker failures around the same timestamp
- confirm the PostgreSQL instance is reachable from the application host

Likely cause in this slice:

- API traffic and Oban both depend on the same PostgreSQL backend

Action:

- restore PostgreSQL connectivity first
- after recovery, inspect queued jobs and retry only reports left in terminal failed states
- review audit logs and report events to distinguish user cancellations from infrastructure failures
